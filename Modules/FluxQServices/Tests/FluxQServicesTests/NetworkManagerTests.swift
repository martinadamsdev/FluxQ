//
//  NetworkManagerTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import Testing
@testable import FluxQServices

@MainActor
struct NetworkManagerTests {

    @Test func initialState() {
        let manager = NetworkManager()
        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test func initWithDefaultPort() {
        let manager = NetworkManager()
        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test func initWithCustomPort() {
        let manager = NetworkManager(port: 3000)
        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test func stopOnFreshManager() {
        let manager = NetworkManager()
        #expect(manager.discoveredUsers.isEmpty)

        manager.stop()

        #expect(manager.discoveredUsers.isEmpty)
    }

    @Test func stopIsIdempotent() {
        let manager = NetworkManager()

        manager.stop()
        manager.stop()

        #expect(manager.discoveredUsers.isEmpty)
    }
}
