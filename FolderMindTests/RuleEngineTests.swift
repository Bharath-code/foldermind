import XCTest

final class RuleEngineTests: XCTestCase {
    var engine: RuleEngine!
    var tempDir: URL!

    override func setUp() async throws {
        engine = RuleEngine.shared
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FolderMindTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testExtensionCondition() async {
        let file = createTestFile(name: "test.pdf")
        let rule = FMRule.mock(conditions: [.extensionIs(["pdf"])])
        let result = await engine.evaluate(rule: rule, for: file)
        XCTAssertTrue(result)
        
        let result2 = await engine.evaluate(rule: FMRule.mock(conditions: [.extensionIs(["png"])]), for: file)
        XCTAssertFalse(result2)
    }

    func testNameContainsCondition() async {
        let file = createTestFile(name: "invoice_2024.pdf")
        let rule = FMRule.mock(conditions: [.nameContains("invoice")])
        let result = await engine.evaluate(rule: rule, for: file)
        XCTAssertTrue(result)
    }

    func testFileSizeCondition() async {
        let file = createTestFile(name: "large.txt", size: 2_000_000) // 2MB
        
        let ruleLarge = FMRule.mock(conditions: [.fileSizeGreaterThan(1)]) // > 1MB
        let resLarge = await engine.evaluate(rule: ruleLarge, for: file)
        XCTAssertTrue(resLarge)
        
        let ruleSmall = FMRule.mock(conditions: [.fileSizeLessThan(1)]) // < 1MB
        let resSmall = await engine.evaluate(rule: ruleSmall, for: file)
        XCTAssertFalse(resSmall)
    }

    func testRegexCondition() async {
        let file = createTestFile(name: "order-123.pdf")
        let rule = FMRule.mock(conditions: [.nameMatchesRegex("order-\\d+")])
        let result = await engine.evaluate(rule: rule, for: file)
        XCTAssertTrue(result)
    }

    func testLogicAllVsAny() async {
        let file = createTestFile(name: "invoice.pdf")
        
        // ALL: pdf AND invoice -> TRUE
        let ruleAllTrue = FMRule.mock(conditions: [.extensionIs(["pdf"]), .nameContains("invoice")], logic: .all)
        let resAllTrue = await engine.evaluate(rule: ruleAllTrue, for: file)
        XCTAssertTrue(resAllTrue)
        
        // ALL: pdf AND photo -> FALSE
        let ruleAllFalse = FMRule.mock(conditions: [.extensionIs(["pdf"]), .nameContains("photo")], logic: .all)
        let resAllFalse = await engine.evaluate(rule: ruleAllFalse, for: file)
        XCTAssertFalse(resAllFalse)
        
        // ANY: pdf OR photo -> TRUE
        let ruleAnyTrue = FMRule.mock(conditions: [.extensionIs(["pdf"]), .nameContains("photo")], logic: .any)
        let resAnyTrue = await engine.evaluate(rule: ruleAnyTrue, for: file)
        XCTAssertTrue(resAnyTrue)
    }

    // MARK: - Helpers

    private func createTestFile(name: String, size: Int = 0) -> URL {
        let url = tempDir.appendingPathComponent(name)
        let data = Data(repeating: 0, count: size)
        try! data.write(to: url)
        return url
    }
}

extension FMRule {
    static func mock(conditions: [RuleCondition], logic: ConditionLogic = .all) -> FMRule {
        FMRule(
            id: UUID(),
            name: "Mock Rule",
            isEnabled: true,
            watchedFolderURL: URL(fileURLWithPath: "/tmp"),
            conditions: conditions,
            conditionLogic: logic,
            actions: [],
            priority: 100
        )
    }
}
