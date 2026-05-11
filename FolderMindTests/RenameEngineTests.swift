import XCTest

final class RenameEngineTests: XCTestCase {
    
    func testTokenReplacement() {
        let fileURL = URL(fileURLWithPath: "/docs/invoice_2023.pdf")
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 5, day: 20))!
        
        // {name}
        XCTAssertEqual(RenameEngine.apply(template: "{name}_copy", to: fileURL, date: date), "invoice_2023_copy.pdf")
        
        // {ext}
        XCTAssertEqual(RenameEngine.apply(template: "new_file.{ext}", to: fileURL, date: date), "new_file.pdf")
        
        // {date} -> YYYY-MM-DD
        XCTAssertEqual(RenameEngine.apply(template: "Archive_{date}", to: fileURL, date: date), "Archive_2024-05-20.pdf")
        
        // {year}, {month}, {day}
        XCTAssertEqual(RenameEngine.apply(template: "{year}-{month}-{day}-backup", to: fileURL, date: date), "2024-05-20-backup.pdf")
    }
    
    func testNestedExtensions() {
        let fileURL = URL(fileURLWithPath: "/docs/archive.tar.gz")
        XCTAssertEqual(RenameEngine.apply(template: "{name}_v2", to: fileURL, date: Date()), "archive.tar_v2.gz")
    }
    
    func testNoTokens() {
        let fileURL = URL(fileURLWithPath: "/docs/old.txt")
        XCTAssertEqual(RenameEngine.apply(template: "static_name", to: fileURL, date: Date()), "static_name.txt")
    }
}
