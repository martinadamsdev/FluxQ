import Foundation
import Testing
@testable import FluxQModels

@Test("用户初始化")
func userInitialization() {
    let user = User(
        id: "192.168.1.100:2425",
        nickname: "Alice",
        hostname: "MacBook-Pro",
        ipAddress: "192.168.1.100"
    )

    #expect(user.id == "192.168.1.100:2425")
    #expect(user.nickname == "Alice")
    #expect(user.ipAddress == "192.168.1.100")
    #expect(user.port == 2425)
    #expect(user.isOnline)
    #expect(user.status == .online)
}

@Test("用户状态显示名称")
func userStatusDisplayName() {
    #expect(UserStatus.online.displayName == "在线")
    #expect(UserStatus.away.displayName == "离开")
    #expect(UserStatus.busy.displayName == "忙碌")
    #expect(UserStatus.offline.displayName == "离线")
}

@Test("头像数据持久化")
func avatarDataPersistence() {
    let sampleData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
    let user = User(
        id: "192.168.1.101:2425",
        nickname: "Bob",
        hostname: "iMac-Pro",
        ipAddress: "192.168.1.101",
        avatarData: sampleData,
        avatarHash: "abc123def456"
    )

    #expect(user.avatarData == sampleData)
    #expect(user.avatarHash == "abc123def456")

    // Test nil defaults
    let userNoAvatar = User(
        id: "192.168.1.102:2425",
        nickname: "Charlie",
        hostname: "MacBook-Air",
        ipAddress: "192.168.1.102"
    )
    #expect(userNoAvatar.avatarData == nil)
    #expect(userNoAvatar.avatarHash == nil)
}

@Test("在线状态追踪")
func onlineStatusTracking() {
    let specificDate = Date(timeIntervalSince1970: 1700000000)
    let user = User(
        id: "192.168.1.103:2425",
        nickname: "Dave",
        hostname: "Mac-Mini",
        ipAddress: "192.168.1.103",
        isOnline: false,
        lastSeen: specificDate
    )

    #expect(!user.isOnline)
    #expect(user.lastSeen == specificDate)

    // Test default values
    let onlineUser = User(
        id: "192.168.1.104:2425",
        nickname: "Eve",
        hostname: "MacBook",
        ipAddress: "192.168.1.104"
    )
    #expect(onlineUser.isOnline)
}
