//
//  DiscoveredUserTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import XCTest
@testable import FluxQServices

final class DiscoveredUserTests: XCTestCase {

    func testInitWithDefaults() {
        // When
        let user = DiscoveredUser(
            id: "alice",
            nickname: "Alice",
            hostname: "MacBook-Pro",
            ipAddress: "192.168.1.10"
        )

        // Then
        XCTAssertEqual(user.id, "alice")
        XCTAssertEqual(user.nickname, "Alice")
        XCTAssertEqual(user.hostname, "MacBook-Pro")
        XCTAssertEqual(user.ipAddress, "192.168.1.10")
        XCTAssertEqual(user.port, 2425)
        XCTAssertNil(user.group)
    }

    func testInitWithCustomValues() {
        // Given
        let date = Date(timeIntervalSince1970: 1000)

        // When
        let user = DiscoveredUser(
            id: "bob",
            nickname: "Bob",
            hostname: "iMac",
            ipAddress: "10.0.0.5",
            port: 3000,
            group: "Engineering",
            discoveredAt: date
        )

        // Then
        XCTAssertEqual(user.id, "bob")
        XCTAssertEqual(user.nickname, "Bob")
        XCTAssertEqual(user.hostname, "iMac")
        XCTAssertEqual(user.ipAddress, "10.0.0.5")
        XCTAssertEqual(user.port, 3000)
        XCTAssertEqual(user.group, "Engineering")
        XCTAssertEqual(user.discoveredAt, date)
    }

    func testEquatable() {
        // Given
        let date = Date(timeIntervalSince1970: 500)
        let user1 = DiscoveredUser(
            id: "user1",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )
        let user2 = DiscoveredUser(
            id: "user1",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )

        // Then
        XCTAssertEqual(user1, user2)
    }

    func testNotEqual() {
        // Given
        let date = Date(timeIntervalSince1970: 500)
        let user1 = DiscoveredUser(
            id: "user1",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )
        let user2 = DiscoveredUser(
            id: "user2",
            nickname: "User",
            hostname: "host",
            ipAddress: "1.2.3.4",
            discoveredAt: date
        )

        // Then
        XCTAssertNotEqual(user1, user2)
    }

    func testIdentifiable() {
        // Given
        let user = DiscoveredUser(
            id: "unique-id",
            nickname: "Test",
            hostname: "host",
            ipAddress: "1.2.3.4"
        )

        // Then - id should match the init parameter
        XCTAssertEqual(user.id, "unique-id")
    }

    func testToUser() {
        // Given
        let date = Date(timeIntervalSince1970: 2000)
        let discoveredUser = DiscoveredUser(
            id: "alice",
            nickname: "Alice",
            hostname: "MacBook",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: "Dev",
            discoveredAt: date
        )

        // When
        let user = discoveredUser.toUser()

        // Then
        XCTAssertEqual(user.id, "alice")
        XCTAssertEqual(user.nickname, "Alice")
        XCTAssertEqual(user.hostname, "MacBook")
        XCTAssertEqual(user.ipAddress, "192.168.1.10")
        XCTAssertEqual(user.port, 2425)
        XCTAssertEqual(user.group, "Dev")
        XCTAssertTrue(user.isOnline)
        XCTAssertEqual(user.lastSeen, date)
    }
}
