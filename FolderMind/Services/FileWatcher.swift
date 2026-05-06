import Foundation

actor FileWatcher {
    private var streamRef: FSEventStreamRef?
    private let watchedURL: URL
    private let debouncer = EventDebouncer(window: 0.5)
    private var onChange: ([FileEvent]) async -> Void

    init(watchedURL: URL, onChange: @escaping ([FileEvent]) async -> Void) {
        self.watchedURL = watchedURL
        self.onChange = onChange
    }

    func start() throws {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )

        let callback: FSEventStreamCallback = {
            _, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            let flags = eventFlags.withMemoryRebound(to: FSEventStreamEventFlags.self, capacity: numEvents) {
                Array(UnsafeBufferPointer(start: $0, count: numEvents))
            }

            Task {
                await self.handleEvents(paths: paths, flags: flags)
            }
        }

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagUseCFTypes)

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [watchedURL.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        )

        guard let stream = streamRef else {
            throw FileWatcherError.streamCreationFailed
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
    }

    private func handleEvents(paths: [String], flags: [FSEventStreamEventFlags]) async {
        let events = zip(paths, flags).compactMap { path, flag -> FileEvent? in
            FileEvent(path: path, flags: flag)
        }

        let stableEvents = await debouncer.add(events)
        guard !stableEvents.isEmpty else { return }

        await onChange(stableEvents)
    }
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
        try? await timerTask?.value
        let result = buffer
        buffer.removeAll()
        return result
    }
}

enum FileWatcherError: Error {
    case streamCreationFailed
}
