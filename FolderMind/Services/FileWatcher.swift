import Foundation

final class FileWatcher: @unchecked Sendable {
    private var streamRef: FSEventStreamRef?
    private let watchedURL: URL
    private let debouncer: EventDebouncer       // assigned in init
    private let onChange: @Sendable ([FileEvent]) async -> Void
    private let eventQueue = DispatchQueue(label: "com.foldermind.filewatcher", qos: .utility)
    private var contextPtr: UnsafeMutableRawPointer?
    private var isRunning = false

    init(watchedURL: URL, onChange: @escaping @Sendable ([FileEvent]) async -> Void) {
        self.watchedURL = watchedURL
        self.onChange = onChange
        // Wire the onChange directly into the debouncer at init — no async juggling.
        self.debouncer = EventDebouncer(window: 0.5, onDeliver: onChange)
    }


    deinit {
        print("[FileWatcher] Deinit for \(watchedURL.path)")
        stop()
    }

    func start() throws {
        isRunning = false

        // Allocate a context struct on the heap — it must outlive the stream.
        let ctx = UnsafeMutablePointer<FileWatcherContext>.allocate(capacity: 1)
        ctx.initialize(to: FileWatcherContext(watcher: self))
        contextPtr = UnsafeMutableRawPointer(ctx)

        var fsContext = FSEventStreamContext(
            version: 0,
            info: contextPtr,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes) |
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagNoDefer) |
            UInt32(kFSEventStreamCreateFlagWatchRoot)

        let paths = [watchedURL.path as CFString] as CFArray

        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            fileWatcherCallback,
            &fsContext,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1, // Reduced latency for snappier response
            flags
        )

        guard let stream = streamRef else {
            ctx.deinitialize(count: 1)
            ctx.deallocate()
            contextPtr = nil
            throw FileWatcherError.streamCreationFailed
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        let started = FSEventStreamStart(stream)
        guard started else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
            ctx.deinitialize(count: 1)
            ctx.deallocate()
            contextPtr = nil
            throw FileWatcherError.streamStartFailed
        }

        // Force a flush to trigger the initial event if requested
        FSEventStreamFlushAsync(stream)

        isRunning = true
        print("[FileWatcher] Started watching \(watchedURL.path)")
    }

    func stop() {
        guard let stream = streamRef, isRunning else { return }
        isRunning = false

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil

        if let ptr = contextPtr {
            let ctx = ptr.assumingMemoryBound(to: FileWatcherContext.self)
            ctx.deinitialize(count: 1)
            ctx.deallocate()
            contextPtr = nil
        }

        print("[FileWatcher] Stopped watching \(watchedURL.path)")
    }

    fileprivate func _handleEvents(paths: [String], flags: [UInt32]) {
        let events = zip(paths, flags).compactMap { FileEvent(path: $0, flags: $1) }
        guard !events.isEmpty else { return }
        print("[FileWatcher] Raw events: \(events.map { "\($0.path.split(separator: "/").last ?? "") [\($0.type)]" })")
        // add() is synchronous — safe to call from the C callback dispatch queue.
        Task { await debouncer.add(events) }
    }
}

private struct FileWatcherContext {
    unowned let watcher: FileWatcher
}

/// Raw C callback — MUST be a global function, not a closure.
/// Cannot call actor-isolated methods directly.
private func fileWatcherCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    print("[FileWatcher] fileWatcherCallback invoked, numEvents=\(numEvents)")

    guard let info = clientCallBackInfo else {
        print("[FileWatcher] No clientCallBackInfo!")
        return
    }

    let ctx = info.assumingMemoryBound(to: FileWatcherContext.self).pointee
    let watcher = ctx.watcher

    // Decode CFArray of CFStrings → [String].
    let cfArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
    guard let paths = cfArray as? [String] else {
        print("[FileWatcher] Could not cast eventPaths to [String]")
        return
    }

    // Decode flags buffer → [UInt32].
    let flags = eventFlags.withMemoryRebound(to: UInt32.self, capacity: numEvents) {
        Array(UnsafeBufferPointer(start: $0, count: numEvents))
    }

    print("[FileWatcher] Paths: \(paths)")
    print("[FileWatcher] Flags: \(flags)")

    // Dispatch synchronously to avoid race with stop().
    watcher._handleEvents(paths: paths, flags: flags)
}

struct FileEvent: Sendable {
    let path: String
    let type: EventType
    let timestamp: Date

    init?(path: String, flags: UInt32) {
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
            // Special events like InitialEvent often have flag 0 or internal system flags.
            // We treat these as 'modified' to trigger a scan of the folder.
            print("[FileEvent] Special event (Flags: \(flags)) for: \(path)")
            self.type = .modified
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
    private var onDeliver: (([FileEvent]) async -> Void)?

    init(window: TimeInterval, onDeliver: @escaping @Sendable ([FileEvent]) async -> Void) {
        self.window = window
        self.onDeliver = onDeliver
    }

    func add(_ events: [FileEvent]) {
        buffer.append(contentsOf: events)

        // Reset the debounce window on each new batch.
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64((self?.window ?? 0.5) * 1_000_000_000))
            } catch {
                return // cancelled — a newer batch arrived
            }
            await self?.flush()
        }
    }

    private func flush() async {
        guard !buffer.isEmpty else { return }
        let events = buffer
        buffer.removeAll()
        timerTask = nil
        await onDeliver?(events)
    }
}

enum FileWatcherError: Error {
    case streamCreationFailed
    case streamStartFailed
}

