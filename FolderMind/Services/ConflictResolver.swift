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
        keepExtension: Bool = true
    ) -> Resolution {
        let fm = FileManager.default

        if !fm.fileExists(atPath: destinationFolder.path) {
            do {
                try fm.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            } catch {
                return .error("Couldn't create folder: \(error.localizedDescription)")
            }
        }

        var destination = destinationFolder.appendingPathComponent(source.lastPathComponent)

        if fm.fileExists(atPath: destination.path) {
            let name = source.deletingPathExtension().lastPathComponent
            let ext = keepExtension ? source.pathExtension : ""
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
