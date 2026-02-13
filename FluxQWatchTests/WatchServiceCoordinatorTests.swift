import Testing
import Foundation
@testable import FluxQWatch

@MainActor
@Test("Switch to companion mode starts connectivity service")
func testSwitchToCompanionMode() async throws {
    let coordinator = WatchServiceCoordinator(testMode: true)
    try await coordinator.switchToMode(.companion)

    #expect(coordinator.activeMode == .companion)
    #expect(coordinator.isConnectivityActive == true)
    #expect(coordinator.isNetworkServiceActive == false)
}

@MainActor
@Test("Switch to standalone mode starts network service")
func testSwitchToStandaloneMode() async throws {
    let coordinator = WatchServiceCoordinator(testMode: true)
    try await coordinator.switchToMode(.standalone)

    #expect(coordinator.activeMode == .standalone)
    #expect(coordinator.isConnectivityActive == false)
    #expect(coordinator.isNetworkServiceActive == true)
}

@MainActor
@Test("Switch to offline mode stops all services")
func testSwitchToOfflineMode() async throws {
    let coordinator = WatchServiceCoordinator(testMode: true)
    try await coordinator.switchToMode(.companion)
    try await coordinator.switchToMode(.offline)

    #expect(coordinator.activeMode == .offline)
    #expect(coordinator.isConnectivityActive == false)
    #expect(coordinator.isNetworkServiceActive == false)
}

@MainActor
@Test("Mode switch stops previous mode services")
func testModeSwitchStopsPrevious() async throws {
    let coordinator = WatchServiceCoordinator(testMode: true)
    try await coordinator.switchToMode(.companion)
    #expect(coordinator.isConnectivityActive == true)

    try await coordinator.switchToMode(.standalone)
    #expect(coordinator.isConnectivityActive == false)
    #expect(coordinator.isNetworkServiceActive == true)
}
