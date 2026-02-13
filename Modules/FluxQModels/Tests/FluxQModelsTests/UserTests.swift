import XCTest
@testable import FluxQModels

final class UserTests: XCTestCase {
    func testUserInitialization() {
        let user = User(
            id: "192.168.1.100:2425",
            nickname: "Alice",
            hostname: "MacBook-Pro",
            ipAddress: "192.168.1.100"
        )

        XCTAssertEqual(user.id, "192.168.1.100:2425")
        XCTAssertEqual(user.nickname, "Alice")
        XCTAssertEqual(user.ipAddress, "192.168.1.100")
        XCTAssertEqual(user.port, 2425)
        XCTAssertTrue(user.isOnline)
        XCTAssertEqual(user.status, .online)
    }

    func testUserStatusDisplayName() {
        XCTAssertEqual(UserStatus.online.displayName, "在线")
        XCTAssertEqual(UserStatus.away.displayName, "离开")
        XCTAssertEqual(UserStatus.busy.displayName, "忙碌")
        XCTAssertEqual(UserStatus.offline.displayName, "离线")
    }
}
