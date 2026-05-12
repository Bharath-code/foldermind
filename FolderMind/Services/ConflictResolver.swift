import Foundation

struct ConflictResolver {
    enum Resolution {
        case move(URL, URL)
        case skip
        case error(String)
    }

    static func resolve(
        source: URL,
        destinationFolder: URL,
        desiredName: String? = nil,
        keepExtension: Bool = true
    ) -> Resolution {
        let fm = FileManager.default

        if !fm.fileExists(atPath: destinationFolder.path) {
            do {
                try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            } catch {
                return .error("Couldn't create folder: \(ErrorMapper.userFriendlyError(from: error))")
            }
        }

        let targetName = desiredName ?? source.lastPathComponent
        var destination = destinationFolder.appendingPathComponent(targetName)

        // If source and destination are identical, skip.
        if destination.standardizedFileURL == source.standardizedFileURL {
            return .skip
        }

        // Only resolve conflicts if destination exists.
        if fm.fileExists(atPath: destination.path) {
            let name = (targetName as NSString).deletingPathExtension
            let ext = keepExtension ? (targetName as NSString).pathExtension : ""
            var counter = 1

            repeat {
                let newName = ext.isEmpty
                    ? "\(name)_\(String(format: "%03d", counter))"
                    : "\(name)_\(String(format: "%03d", counter)).\(ext)"
                destination = destinationFolder.appendingPathComponent(newName)
                counter += 1
            } while fm.fileExists(atPath: destination.path)
        }

        return .move(source, destination)
    }
}
