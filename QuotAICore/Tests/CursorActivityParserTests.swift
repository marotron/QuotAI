import XCTest
@testable import QuotAICore

final class CursorActivityParserTests: XCTestCase {
    func testExtractsSelectedRuntimeTurnsAndDeduplicatesGenerationUUID() {
        let log = """
        2026-11-07 15:17:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"a83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"default"}
        unrelated log record
        2026-11-07 15:18:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"b83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"gpt-5.6-terra"}
        2026-11-07 15:19:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"a83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"default"}
        2026-11-07 15:20:31.544 [info] Selected Agent Host turn runtime {"generationUUID":"","modelId":"default"}
        """

        let turns = CursorActivityParser.parse(log: log)

        XCTAssertEqual(turns.map(\.generationUUID), [
            "a83679db-f9e5-4e72-8b56-c60449e43f3f",
            "b83679db-f9e5-4e72-8b56-c60449e43f3f",
        ])
        XCTAssertEqual(turns.map(\.meter), [.cursorModels, .otherModels])
        XCTAssertEqual(turns[0].modelID, "auto")
        XCTAssertEqual(turns[1].modelID, "gpt-5.6-terra")
    }

    func testComposerAndGrokModelIdsMapToCursorModelsPool() {
        let log = """
        2026-11-07 15:17:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"a83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"composer-2.5-fast"}
        2026-11-07 15:18:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"b83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"Composer-2-fast"}
        2026-11-07 15:19:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"c83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"grok-code"}
        2026-11-07 15:20:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"d83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"cursor-grok-4.5-high"}
        """

        let turns = CursorActivityParser.parse(log: log)

        XCTAssertEqual(turns.map(\.meter), [
            .cursorModels, .cursorModels, .cursorModels, .cursorModels,
        ])
        XCTAssertEqual(turns.map(\.modelID), [
            "composer-2.5-fast", "Composer-2-fast", "grok-code", "cursor-grok-4.5-high",
        ])
    }

    func testClassifyMatchesUsageCsvSpendingPools() {
        XCTAssertEqual(CursorActivityParser.classify(modelID: "composer-2.5-fast").meter, .cursorModels)
        XCTAssertEqual(CursorActivityParser.classify(modelID: "composer-2.5").meter, .cursorModels)
        XCTAssertEqual(CursorActivityParser.classify(modelID: "auto").meter, .cursorModels)
        XCTAssertEqual(CursorActivityParser.classify(modelID: "auto").storedModelID, "auto")
        XCTAssertEqual(CursorActivityParser.classify(modelID: "default").meter, .cursorModels)
        XCTAssertEqual(CursorActivityParser.classify(modelID: "default").storedModelID, "auto")
        XCTAssertEqual(CursorActivityParser.classify(modelID: "cursor-grok-4.5-high").meter, .cursorModels)
        XCTAssertEqual(CursorActivityParser.classify(modelID: "grok-bot-default").meter, .otherModels)
        XCTAssertEqual(CursorActivityParser.classify(modelID: "gpt-5.6-terra-medium").meter, .otherModels)
        XCTAssertEqual(CursorActivityParser.classify(modelID: "claude-haiku-5-5").meter, .otherModels)
    }

    func testClaudeAndOtherThirdPartyIdsMapToOtherModelsPool() {
        let log = """
        2026-11-07 15:17:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"a83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"claude-4-sonnet"}
        2026-11-07 15:18:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"b83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"gpt-5.6-terra"}
        2026-11-07 15:19:31.544 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"c83679db-f9e5-4e72-8b56-c60449e43f3f","modelId":"gemini-2.5-pro"}
        """

        let turns = CursorActivityParser.parse(log: log)

        XCTAssertEqual(turns.map(\.meter), [
            .otherModels, .otherModels, .otherModels,
        ])
        XCTAssertEqual(turns.map(\.modelID), [
            "claude-4-sonnet", "gpt-5.6-terra", "gemini-2.5-pro",
        ])
    }

    func testSetsEndedAtFromLaterActivityMentioningGenerationUUID() throws {
        let uuid = "a83679db-f9e5-4e72-8b56-c60449e43f3f"
        let log = """
        2026-11-04 13:54:01.100 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"\(uuid)","modelId":"gpt-5.6-terra"}
        2026-11-04 14:10:00.000 [info] Request successful
        2026-11-04 14:35:12.456 [info] toolCall requestId=\(uuid) status=running
        2026-11-04 14:46:00.789 [info] invocation=\(uuid) completed
        """

        let turns = CursorActivityParser.parse(log: log)

        XCTAssertEqual(turns.count, 1)
        let ended = try XCTUnwrap(turns[0].endedAt)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        XCTAssertEqual(ended, formatter.date(from: "2026-11-04 14:46:00.789"))
    }

    func testIgnoresActivityForUnknownGenerationUUID() {
        let known = "a83679db-f9e5-4e72-8b56-c60449e43f3f"
        let unknown = "b83679db-f9e5-4e72-8b56-c60449e43f3f"
        let log = """
        2026-11-04 13:54:01.100 [info] Selected Agent Host turn runtime {"runtime":"managed-local","generationUUID":"\(known)","modelId":"default"}
        2026-11-04 14:46:00.789 [info] requestId=\(unknown) still going
        """

        let turns = CursorActivityParser.parse(log: log)

        XCTAssertEqual(turns.count, 1)
        XCTAssertNil(turns[0].endedAt)
    }
}
