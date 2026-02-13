import Testing
import Foundation
@testable import IPMsgProtocol

@Suite("IPMsgError Tests")
struct IPMsgErrorTests {

    // MARK: - Error conformance

    @Test("IPMsgError conforms to Error protocol")
    func errorConformance() {
        let error: any Error = IPMsgError.timeout
        #expect(error is IPMsgError)
    }

    @Test("IPMsgError conforms to LocalizedError protocol")
    func localizedErrorConformance() {
        let error: any LocalizedError = IPMsgError.timeout
        #expect(error.errorDescription != nil)
    }

    // MARK: - errorDescription for each case

    @Test("invalidFormat errorDescription includes details")
    func invalidFormatDescription() {
        let error = IPMsgError.invalidFormat("missing colon separator")
        #expect(error.errorDescription == "Invalid message format: missing colon separator")
    }

    @Test("networkError errorDescription includes details")
    func networkErrorDescription() {
        let error = IPMsgError.networkError("connection refused")
        #expect(error.errorDescription == "Network error: connection refused")
    }

    @Test("timeout errorDescription")
    func timeoutDescription() {
        let error = IPMsgError.timeout
        #expect(error.errorDescription == "Operation timed out")
    }

    @Test("invalidCommand errorDescription includes command code")
    func invalidCommandDescription() {
        let error = IPMsgError.invalidCommand(9999)
        #expect(error.errorDescription == "Invalid command code: 9999")
    }

    // MARK: - Associated values

    @Test("invalidFormat preserves associated string")
    func invalidFormatAssociatedValue() {
        let error = IPMsgError.invalidFormat("test detail")
        if case .invalidFormat(let details) = error {
            #expect(details == "test detail")
        } else {
            Issue.record("Expected invalidFormat case")
        }
    }

    @Test("networkError preserves associated string")
    func networkErrorAssociatedValue() {
        let error = IPMsgError.networkError("socket closed")
        if case .networkError(let details) = error {
            #expect(details == "socket closed")
        } else {
            Issue.record("Expected networkError case")
        }
    }

    @Test("invalidCommand preserves associated code")
    func invalidCommandAssociatedValue() {
        let error = IPMsgError.invalidCommand(42)
        if case .invalidCommand(let code) = error {
            #expect(code == 42)
        } else {
            Issue.record("Expected invalidCommand case")
        }
    }

    // MARK: - Edge cases

    @Test("invalidFormat with empty string")
    func invalidFormatEmptyString() {
        let error = IPMsgError.invalidFormat("")
        #expect(error.errorDescription == "Invalid message format: ")
    }

    @Test("networkError with empty string")
    func networkErrorEmptyString() {
        let error = IPMsgError.networkError("")
        #expect(error.errorDescription == "Network error: ")
    }

    @Test("invalidCommand with zero")
    func invalidCommandZero() {
        let error = IPMsgError.invalidCommand(0)
        #expect(error.errorDescription == "Invalid command code: 0")
    }

    @Test("invalidCommand with negative value")
    func invalidCommandNegative() {
        let error = IPMsgError.invalidCommand(-1)
        #expect(error.errorDescription == "Invalid command code: -1")
    }
}
