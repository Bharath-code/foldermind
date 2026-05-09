import Foundation

enum RenameEngine {
    static func apply(template: String, to url: URL, date: Date = Date()) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let formatter = DateFormatter()

        var result = template

        result = result.replacingOccurrences(of: "{name}", with: name)
        result = result.replacingOccurrences(of: "{ext}", with: ext)

        formatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{date}", with: formatter.string(from: date))

        formatter.dateFormat = "yyyy"
        result = result.replacingOccurrences(of: "{year}", with: formatter.string(from: date))

        formatter.dateFormat = "MM"
        result = result.replacingOccurrences(of: "{month}", with: formatter.string(from: date))

        formatter.dateFormat = "dd"
        result = result.replacingOccurrences(of: "{day}", with: formatter.string(from: date))

        formatter.dateFormat = "HH-mm-ss"
        result = result.replacingOccurrences(of: "{time}", with: formatter.string(from: date))

        result = result.replacingOccurrences(of: "{parent}", with: url.deletingLastPathComponent().lastPathComponent)

        // Append extension only if it isn't already part of the result.
        if !ext.isEmpty && !result.hasSuffix(".\(ext)") {
            return "\(result).\(ext)"
        }
        return result
    }

    static func preview(template: String, for fileName: String, date: Date = Date()) -> String {
        let url = URL(fileURLWithPath: "/tmp/\(fileName)")
        return apply(template: template, to: url, date: date)
    }
}
