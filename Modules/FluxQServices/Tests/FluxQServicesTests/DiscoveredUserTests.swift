//
//  DiscoveredUserTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation
import Testing
@testable import FluxQServices

struct DiscoveredUserTests {

    @Test func initWithDefaults() {
        let user = DiscoveredUser(
            senderName: "alice",
            nickname: "Alice",
            hostname: "MacBook-Pro",
            ipAddress: "192.168.1.10"
        )

        #expect(user.senderName == "alice")
        #expect(user.nickname == "Alice")
        #expect(user.hostname == "MacBook-Pro")
        #expect(user.ipAddress == "192.168.1.10")
        #expect(user.port == 2425)
        #expect(user.group == nil)
    }

    @Test func initWithCustomValues() {
        let date = Date(timeIntervalSince1970: 1000)
        let testId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let user = DiscoveredUser(
            id: testId,
            senderName: "bob",
            nickname: "Bob",
            hostname: "iMac",
            ipAddress: "10.0.0.5",
            port: 3000,
            group: "Engineering",
            discoveredAt: date
        )

        #expect(user.id == testId)
        #expect(user.senderName == "bob")
        #expect(user.nickname == "Bob")
        #expect(user.hostname == "iMac")
        #expect(user.ipAddress == "10.0.0.5")
        #expect(user.port == 3000)
        #expect(user.group == "Engineering")
        #expect(user.discoveredAt == date)
    }

    @Test func equatable() {
        let date = Date(timeIntervalSince1970: 500)
        let sharedId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let user1 = DiscoveredUser(
            id: sharedId,
            senderName: "user1",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )
        let user2 = DiscoveredUser(
            id: sharedId,
            senderName: "user1",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )

        #expect(user1 == user2)
    }

    @Test func notEqual() {
        let date = Date(timeIntervalSince1970: 500)
        let user1 = DiscoveredUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            senderName: "user1",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )
        let user2 = DiscoveredUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            senderName: "user2",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )

        #expect(user1 != user2)
    }

    @Test func identifiable() {
        let testId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let user = DiscoveredUser(
            id: testId,
            senderName: "unique-sender",
            nickname: "Test",
            hostname: "host",
            ipAddress: "1.2.3.4"
        )

        #expect(user.id == testId)
    }

    @Test func toUser() {
        let date = Date(timeIntervalSince1970: 2000)
        let testId = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        let discoveredUser = DiscoveredUser(
            id: testId,
            senderName: "alice",
            nickname: "Alice",
            hostname: "MacBook",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: "Dev",
            discoveredAt: date
        )

        let user = discoveredUser.toUser()

        #expect(user.id == testId)
        #expect(user.nickname == "Alice")
        #expect(user.hostname == "MacBook")
        #expect(user.ipAddress == "192.168.1.10")
        #expect(user.port == 2425)
        #expect(user.group == "Dev")
        #expect(user.isOnline == true)
        #expect(user.lastSeen == date)
    }
}
