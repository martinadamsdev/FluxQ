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

    func testAvatarDataPersistence() {
        let sampleData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        let user = User(
            id: "192.168.1.101:2425",
            nickname: "Bob",
            hostname: "iMac-Pro",
            ipAddress: "192.168.1.101",
            avatarData: sampleData,
            avatarHash: "abc123def456"
        )

        XCTAssertEqual(user.avatarData, sampleData)
        XCTAssertEqual(user.avatarHash, "abc123def456")

        // Test nil defaults
        let userNoAvatar = User(
            id: "192.168.1.102:2425",
            nickname: "Charlie",
            hostname: "MacBook-Air",
            ipAddress: "192.168.1.102"
        )
        XCTAssertNil(userNoAvatar.avatarData)
        XCTAssertNil(userNoAvatar.avatarHash)
    }

    func testOnlineStatusTracking() {
        let specificDate = Date(timeIntervalSince1970: 1700000000)
        let user = User(
            id: "192.168.1.103:2425",
            nickname: "Dave",
            hostname: "Mac-Mini",
            ipAddress: "192.168.1.103",
            isOnline: false,
            lastSeen: specificDate
        )

        XCTAssertFalse(user.isOnline)
        XCTAssertEqual(user.lastSeen, specificDate)

        // Test default values
        let onlineUser = User(
            id: "192.168.1.104:2425",
            nickname: "Eve",
            hostname: "MacBook",
            ipAddress: "192.168.1.104"
        )
        XCTAssertTrue(onlineUser.isOnline)
    }
}
