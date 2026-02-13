import Testing
import Foundation
@testable import FluxQServices
import FluxQModels

@MainActor
struct SearchFilterServiceTests {

    // MARK: - Helpers

    private func createUser(
        id: String = UUID().uuidString,
        nickname: String = "TestUser",
        hostname: String = "test-host",
        ipAddress: String = "192.168.1.1",
        group: String? = nil,
        isOnline: Bool = true,
        lastSeen: Date = Date(),
        avatarHash: String? = nil
    ) -> User {
        User(
            id: id,
            nickname: nickname,
            hostname: hostname,
            ipAddress: ipAddress,
            group: group,
            isOnline: isOnline,
            lastSeen: lastSeen,
            avatarHash: avatarHash
        )
    }

    // MARK: - Search Tests

    @Test("Search by nickname returns matching users")
    func testSearchByNickname() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "Alice"),
            createUser(nickname: "Bob"),
            createUser(nickname: "AliceWonder"),
        ]

        service.searchText = "Alice"
        let results = service.filterUsers(users)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.nickname.contains("Alice") })
    }

    @Test("Search by hostname returns matching users")
    func testSearchByHostname() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "User1", hostname: "mac-studio"),
            createUser(nickname: "User2", hostname: "macbook-pro"),
            createUser(nickname: "User3", hostname: "windows-pc"),
        ]

        service.searchText = "mac"
        let results = service.filterUsers(users)

        #expect(results.count == 2)
    }

    @Test("Search by group returns matching users")
    func testSearchByGroup() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "User1", group: "Engineering"),
            createUser(nickname: "User2", group: "Design"),
            createUser(nickname: "User3", group: "Engineering Team"),
        ]

        service.searchText = "Engineer"
        let results = service.filterUsers(users)

        #expect(results.count == 2)
    }

    @Test("Search is case insensitive")
    func testSearchCaseInsensitive() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "Alice"),
            createUser(nickname: "bob"),
        ]

        service.searchText = "alice"
        let results = service.filterUsers(users)

        #expect(results.count == 1)
        #expect(results.first?.nickname == "Alice")
    }

    @Test("Empty search text returns all users")
    func testEmptySearchReturnsAll() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "Alice"),
            createUser(nickname: "Bob"),
        ]

        service.searchText = ""
        let results = service.filterUsers(users)

        #expect(results.count == 2)
    }

    // MARK: - Filter Tests

    @Test("Filter by online status")
    func testFilterByOnlineStatus() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "Online1", isOnline: true),
            createUser(nickname: "Offline1", isOnline: false),
            createUser(nickname: "Online2", isOnline: true),
        ]

        service.filters = [.onlineOnly]
        let results = service.filterUsers(users)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.isOnline })
    }

    @Test("Filter by avatar presence")
    func testFilterByAvatarPresence() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "WithAvatar", avatarHash: "abc123"),
            createUser(nickname: "NoAvatar", avatarHash: nil),
            createUser(nickname: "WithAvatar2", avatarHash: "def456"),
        ]

        service.filters = [.withAvatar]
        let results = service.filterUsers(users)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.avatarHash != nil })
    }

    @Test("Filter by recently active")
    func testFilterByRecentlyActive() {
        let service = SearchFilterService()
        let now = Date()
        let users = [
            createUser(nickname: "Recent", lastSeen: now),
            createUser(nickname: "Old", lastSeen: now.addingTimeInterval(-3600)),
            createUser(nickname: "VeryOld", lastSeen: now.addingTimeInterval(-7200)),
        ]

        service.filters = [.recentlyActive]
        let results = service.filterUsers(users)

        #expect(results.count == 1)
        #expect(results.first?.nickname == "Recent")
    }

    // MARK: - Combined Tests

    @Test("Combined search and filter")
    func testCombinedSearchAndFilter() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "Alice", isOnline: true),
            createUser(nickname: "AliceBob", isOnline: false),
            createUser(nickname: "Bob", isOnline: true),
        ]

        service.searchText = "Alice"
        service.filters = [.onlineOnly]
        let results = service.filterUsers(users)

        #expect(results.count == 1)
        #expect(results.first?.nickname == "Alice")
    }

    @Test("Multiple filters applied together")
    func testMultipleFilters() {
        let service = SearchFilterService()
        let now = Date()
        let users = [
            createUser(nickname: "User1", isOnline: true, lastSeen: now, avatarHash: "abc"),
            createUser(nickname: "User2", isOnline: true, lastSeen: now, avatarHash: nil),
            createUser(nickname: "User3", isOnline: false, lastSeen: now, avatarHash: "def"),
            createUser(nickname: "User4", isOnline: true, lastSeen: now.addingTimeInterval(-3600), avatarHash: "ghi"),
        ]

        service.filters = [.onlineOnly, .withAvatar, .recentlyActive]
        let results = service.filterUsers(users)

        #expect(results.count == 1)
        #expect(results.first?.nickname == "User1")
    }

    @Test("No filters returns all users")
    func testNoFiltersReturnsAll() {
        let service = SearchFilterService()
        let users = [
            createUser(nickname: "Alice"),
            createUser(nickname: "Bob"),
        ]

        service.filters = []
        let results = service.filterUsers(users)

        #expect(results.count == 2)
    }
}
