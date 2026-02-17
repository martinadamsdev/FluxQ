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

    @Test func refreshDiscoveryBroadcasts() throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        try manager.start()

        let countBefore = transport.broadcastMessages.count
        try manager.refreshDiscovery()

        #expect(transport.broadcastMessages.count > countBefore, "refreshDiscovery should send a broadcast")
    }

    @Test func networkStatusNotEmptyAfterStart() throws {
        let transport = MockNetworkTransport()
        let manager = NetworkManager(port: 2425, transport: transport)
        try manager.start()
        #expect(!manager.networkStatus.isEmpty, "networkStatus should have a value after start")
        manager.stop()
    }
}
