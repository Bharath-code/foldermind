import Foundation

class FileWatcher {
    private var streamRef: FSEventStreamRef?
    private let watchedURL: URL
    private let debouncer = EventDebouncer(window: 0.5)
    private let onChange: ([FileEvent]) async -> Void
    private let eventQueue = DispatchQueue(label: "com.foldermind.filewatcher")
    private var context: UnsafeMutablePointer<FileWatcherContext>?

    init(watchedURL: URL, onChange: @escaping ([FileEvent]) async -> Void) {
        self.watchedURL = watchedURL
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() throws {
        let ctx = UnsafeMutablePointer<FileWatcherContext>.allocate(capacity: 1)
        ctx.initialize(to: FileWatcherContext(watcher: self))
        context = ctx

        var fsContext = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(ctx),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagUseCFTypes)

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            fileWatcherCallback,
            &fsContext,
            [watchedURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        )

        guard let stream = streamRef else {
            ctx.deinitialize(count: 1)
            ctx.deallocate()
            context = nil
            throw FileWatcherError.streamCreationFailed
        }

        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil

        if let ctx = context {
            ctx.deinitialize(count: 1)
            ctx.deallocate()
            context = nil
        }
    }

    func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) {
        let events = zip(paths, flags).compactMap { path, flag -> FileEvent? in
            FileEvent(path: path, flags: flag)
        }

        Task {
            let stableEvents = await debouncer.add(events)
            guard !stableEvents.isEmpty else { return }
            await onChange(stableEvents)
        }
    }
}

private struct FileWatcherContext {
    let watcher: FileWatcher
}

private func fileWatcherCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let context = clientCallBackInfo?.assumingMemoryBound(to: FileWatcherContext.self) else { return }
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
    let flags = eventFlags.withMemoryRebound(to: FSEventStreamEventFlags.self, capacity: numEvents) {
        Array(UnsafeBufferPointer(start: $0, count: numEvents))
    }
    context.pointee.watcher.handleEvents(paths: paths, flags: flags)
}

struct FileEvent: Sendable {
    let path: String
    let type: EventType
    let timestamp: Date

    init?(path: String, flags: FSEventStreamEventFlags) {
        self.path = path
        self.timestamp = Date()

        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            self.type = .created
        } else if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            self.type = .deleted
        } else if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
            self.type = .modified
        } else if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
            self.type = .moved
        } else {
            return nil
        }
    }

    enum EventType: Sendable {
        case created, modified, moved, deleted
    }
}

actor EventDebouncer {
    private let window: TimeInterval
    private var buffer: [FileEvent] = []
    private var timerTask: Task<Void, Never>?

    init(window: TimeInterval) {
        self.window = window
    }

    func add(_ events: [FileEvent]) async -> [FileEvent] {
        buffer.append(contentsOf: events)
        timerTask?.cancel()
        timerTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            guard !Task.isCancelled else { return }
        }
        await timerTask?.value
        let result = buffer
        buffer.removeAll()
        return result
    }
}

enum FileWatcherError: Error {
    case streamCreationFailed
}
