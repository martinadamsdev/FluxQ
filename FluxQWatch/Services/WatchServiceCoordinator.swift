import Foundation
import Observation

/// Watch 服务协调器
///
/// 根据网络模式协调各服务的启动和停止。
/// companion -> WatchConnectivityService
/// standalone -> WatchNetworkService
/// offline -> 全部停止
@MainActor
@Observable
public class WatchServiceCoordinator {
    // MARK: - State

    public private(set) var activeMode: NetworkModeManager.NetworkMode = .offline
    public private(set) var isConnectivityActive: Bool = false
    public private(set) var isNetworkServiceActive: Bool = false

    // MARK: - Services

    private let connectivityService: WatchConnectivityService
    private let networkService: WatchNetworkService
    private let testMode: Bool

    // MARK: - Init

    public init(
        connectivityService: WatchConnectivityService? = nil,
        networkService: WatchNetworkService? = nil,
        testMode: Bool = false
    ) {
        self.testMode = testMode
        self.connectivityService = connectivityService ?? WatchConnectivityService(testMode: testMode)
        self.networkService = networkService ?? WatchNetworkService(testMode: testMode)
    }

    // MARK: - Mode Switching

    public func switchToMode(_ mode: NetworkModeManager.NetworkMode) async throws {
        guard mode != activeMode else { return }

        // 停止当前模式的服务
        await stopCurrentServices()

        // 启动新模式的服务
        switch mode {
        case .companion:
            try await connectivityService.start()
            isConnectivityActive = true

        case .standalone:
            try await networkService.start()
            isNetworkServiceActive = true

        case .offline:
            break
        }

        activeMode = mode
    }

    private func stopCurrentServices() async {
        if isConnectivityActive {
            connectivityService.stop()
            isConnectivityActive = false
        }

        if isNetworkServiceActive {
            networkService.stop()
            isNetworkServiceActive = false
        }
    }
}
