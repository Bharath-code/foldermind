import XCTest

final class ConflictResolverTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ConflictTests_\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testNoConflict() {
        let source = createTestFile(name: "original.txt")
        let destFolder = tempDir.appendingPathComponent("Destination")
        // No directory exists yet, should create it
        
        let result = ConflictResolver.resolve(source: source, destinationFolder: destFolder, desiredName: "new.txt")
        
        if case .move(let src, let dest) = result {
            XCTAssertEqual(src, source)
            XCTAssertEqual(dest.lastPathComponent, "new.txt")
        } else {
            XCTFail("Should be a move")
        }
    }

    func testNamingConflict() {
        let source = createTestFile(name: "input.txt")
        let destFolder = tempDir.appendingPathComponent("Target")
        try! FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        
        // Create existing file in destination
        let existing = destFolder.appendingPathComponent("report.txt")
        try! "old content".write(to: existing, atomically: true, encoding: .utf8)
        
        let result = ConflictResolver.resolve(source: source, destinationFolder: destFolder, desiredName: "report.txt")
        
        if case .move(_, let dest) = result {
            XCTAssertEqual(dest.lastPathComponent, "report_001.txt")
        } else {
            XCTFail("Should resolve with a counter")
        }
        
        // Create another one
        try! "content 1".write(to: destFolder.appendingPathComponent("report_001.txt"), atomically: true, encoding: .utf8)
        let result2 = ConflictResolver.resolve(source: source, destinationFolder: destFolder, desiredName: "report.txt")
        
        if case .move(_, let dest) = result2 {
            XCTAssertEqual(dest.lastPathComponent, "report_002.txt")
        } else {
            XCTFail("Should resolve with counter 2")
        }
    }

    func testAlreadyAtDestinationSkip() {
        let destFolder = tempDir.appendingPathComponent("Target")
        try! FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
        
        let source = destFolder.appendingPathComponent("same.txt")
        try! "identical".write(to: source, atomically: true, encoding: .utf8)
        
        let result = ConflictResolver.resolve(source: source, destinationFolder: destFolder, desiredName: "same.txt")
        
        if case .skip = result {
            // Correct
        } else {
            XCTFail("Should skip if already at target location")
        }
    }

    // MARK: - Helpers
    private func createTestFile(name: String, content: String = "test") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
