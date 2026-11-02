import XCTest
@testable import QuotAICore

final class CursorSealedTokenTests: XCTestCase {
    func testRoundTripsAJWT() throws {
        let token = makeCursorJWT(sub: "auth0|sealed-user")
        let sealed = try CursorSealedToken.seal(token: token, password: "test-password")

        XCTAssertTrue(CursorSealedToken.isSealed(sealed))
        XCTAssertEqual(CursorSealedToken.open(stored: sealed, password: "test-password"), token)
        XCTAssertNil(CursorSealedToken.open(stored: sealed, password: "other-password"))
        XCTAssertNil(CursorSealedToken.open(stored: "cursor-safe-storage:v1:not-base64", password: "test-password"))
    }

    func testPlaintextIsNotSealed() {
        XCTAssertFalse(CursorSealedToken.isSealed(makeCursorJWT()))
        XCTAssertFalse(CursorSealedToken.isSealed(""))
    }

    func testOpenRejectsNonJWTPlaintextAfterDecrypt() throws {
        let sealed = try CursorSealedToken.seal(token: "not-a-jwt", password: "test-password")
        XCTAssertNil(CursorSealedToken.open(stored: sealed, password: "test-password"))
    }
}

private func makeCursorJWT(sub: String = "auth0|test-user") -> String {
    func b64url(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    let header = b64url(#"{"alg":"none","typ":"JWT"}"#)
    let payload = b64url(#"{"sub":"\#(sub)"}"#)
    return "\(header).\(payload).sig"
}
