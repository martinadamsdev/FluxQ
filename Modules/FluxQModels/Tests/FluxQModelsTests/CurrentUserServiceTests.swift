import Testing
import Foundation
import SwiftData
@testable import FluxQModels

@Suite("CurrentUserService Logic Tests")
struct CurrentUserServiceTests {

    /// Helper: create an in-memory ModelContainer for testing
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: User.self, Conversation.self, Message.self,
            configurations: config
        )
    }

    /// Helper: replicate CurrentUserService.currentUser logic at model layer
    private func findOrCreateCurrentUser(
        hostname: String,
        ipAddress: String,
        nickname: String,
        port: Int = 2425,
        in context: ModelContext
    ) -> User {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate {
                $0.hostname == hostname && $0.ipAddress == ipAddress
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.isOnline = true
            existing.lastSeen = Date()
            return existing
        }

        let user = User(
            nickname: nickname,
            hostname: hostname,
            ipAddress: ipAddress,
            port: port,
            status: .online,
            isOnline: true
        )
        context.insert(user)
        try? context.save()
        return user
    }

    @Test("Find existing user by hostname + ipAddress updates lastSeen and isOnline")
    func findExistingUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // Pre-insert a user that is offline with old lastSeen
        let pastDate = Date.distantPast
        let existingUser = User(
            nickname: "TestDevice",
            hostname: "myhost",
            ipAddress: "127.0.0.1",
            port: 2425,
            status: .online,
            isOnline: false,
            lastSeen: pastDate
        )
        context.insert(existingUser)
        try context.save()

        let result = findOrCreateCurrentUser(
            hostname: "myhost",
            ipAddress: "127.0.0.1",
            nickname: "TestDevice",
            in: context
        )

        // Should return the same user
        #expect(result.id == existingUser.id)

        // Should update isOnline and lastSeen
        #expect(result.isOnline == true)
        #expect(result.lastSeen > pastDate)

        // Should not create a new user
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
    }

    @Test("Create new user when none exists")
    func createNewUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        // No users in the store
        let usersBefore = try context.fetch(FetchDescriptor<User>())
        #expect(usersBefore.count == 0)

        let result = findOrCreateCurrentUser(
            hostname: "newhost",
            ipAddress: "127.0.0.1",
            nickname: "MyDevice",
            port: 2425,
            in: context
        )

        // Should create and return a new user with correct fields
        #expect(result.hostname == "newhost")
        #expect(result.ipAddress == "127.0.0.1")
        #expect(result.nickname == "MyDevice")
        #expect(result.port == 2425)
        #expect(result.isOnline == true)
        #expect(result.status == .online)

        // Should be persisted
        let usersAfter = try context.fetch(FetchDescriptor<User>())
        #expect(usersAfter.count == 1)
        #expect(usersAfter[0].id == result.id)
    }

    @Test("Same hostname + IP called twice is idempotent, count stays 1")
    func idempotentLookup() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let first = findOrCreateCurrentUser(
            hostname: "samehost",
            ipAddress: "127.0.0.1",
            nickname: "Device",
            in: context
        )

        let second = findOrCreateCurrentUser(
            hostname: "samehost",
            ipAddress: "127.0.0.1",
            nickname: "Device",
            in: context
        )

        // Should return the same user both times
        #expect(first.id == second.id)

        // Should have exactly one user in the store
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 1)
    }

    @Test("Different hostname creates separate user")
    func differentHostnameCreatesSeparateUser() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let user1 = findOrCreateCurrentUser(
            hostname: "host-a",
            ipAddress: "127.0.0.1",
            nickname: "DeviceA",
            in: context
        )

        let user2 = findOrCreateCurrentUser(
            hostname: "host-b",
            ipAddress: "127.0.0.1",
            nickname: "DeviceB",
            in: context
        )

        // Should be different users
        #expect(user1.id != user2.id)
        #expect(user1.hostname == "host-a")
        #expect(user2.hostname == "host-b")

        // Should have two users in the store
        let users = try context.fetch(FetchDescriptor<User>())
        #expect(users.count == 2)
    }
}
