//
//  NetworkManagerTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import XCTest
@testable import FluxQServices

@MainActor
final class NetworkManagerTests: XCTestCase {

    var manager: NetworkManager!

    override func setUp() {
        manager = NetworkManager()
    }

    override func tearDown() {
        manager.stop()
        manager = nil
    }

    func testInitialState() {
        // Then - discoveredUsers should be empty on init
        XCTAssertTrue(manager.discoveredUsers.isEmpty)
    }

    func testInitWithDefaultPort() {
        // When
        let mgr = NetworkManager()

        // Then - should be created without error
        XCTAssertTrue(mgr.discoveredUsers.isEmpty)
    }

    func testInitWithCustomPort() {
        // When
        let mgr = NetworkManager(port: 3000)

        // Then - should be created without error
        XCTAssertTrue(mgr.discoveredUsers.isEmpty)
    }

    func testStopOnFreshManager() {
        // Given - a fresh manager with no discovered users
        XCTAssertTrue(manager.discoveredUsers.isEmpty)

        // When
        manager.stop()

        // Then - should remain empty and not crash
        XCTAssertTrue(manager.discoveredUsers.isEmpty)
    }

    func testStopIsIdempotent() {
        // When - calling stop multiple times should not crash
        manager.stop()
        manager.stop()

        // Then
        XCTAssertTrue(manager.discoveredUsers.isEmpty)
    }
}
