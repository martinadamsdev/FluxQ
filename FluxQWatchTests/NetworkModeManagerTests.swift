import Testing
import Foundation
@testable import FluxQWatch

@Test("Detect companion mode when iPhone reachable")
@MainActor
func testDetectCompanionMode() {
    let manager = NetworkModeManager(testMode: true)
    manager.mockWCSessionReachable = true

    let mode = manager.determineNetworkMode()
    #expect(mode == .companion)
}

@Test("Detect standalone mode when Wi-Fi available")
@MainActor
func testDetectStandaloneMode() {
    let manager = NetworkModeManager(testMode: true)
    manager.mockWCSessionReachable = false
    manager.mockWiFiEnabled = true

    let mode = manager.determineNetworkMode()
    #expect(mode == .standalone)
}

@Test("Detect offline mode when no connectivity")
@MainActor
func testDetectOfflineMode() {
    let manager = NetworkModeManager(testMode: true)
    manager.mockWCSessionReachable = false
    manager.mockWiFiEnabled = false

    let mode = manager.determineNetworkMode()
    #expect(mode == .offline)
}
