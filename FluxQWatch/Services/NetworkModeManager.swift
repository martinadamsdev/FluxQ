import Foundation
import Network
import WatchConnectivity
import Observation

@MainActor
@Observable
public class NetworkModeManager {
    public private(set) var currentMode: NetworkMode = .offline

    public enum NetworkMode: Equatable {
        case companion
        case standalone
        case offline
    }

    private let testMode: Bool
    var mockWCSessionReachable: Bool = false
    var mockWiFiEnabled: Bool = false

    private var wiFiAvailable: Bool = false
    private var pathMonitor: NWPathMonitor?

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    public func startMonitoring() {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.wiFiAvailable = path.status == .satisfied
                self?.updateNetworkMode()
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        pathMonitor = monitor

        Task {
            while !Task.isCancelled {
                updateNetworkMode()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func updateNetworkMode() {
        let newMode = determineNetworkMode()

        if newMode != currentMode {
            currentMode = newMode
            Task {
                try? await switchToMode(newMode)
            }
        }
    }

    func determineNetworkMode() -> NetworkMode {
        if testMode {
            if mockWCSessionReachable {
                return .companion
            } else if mockWiFiEnabled {
                return .standalone
            } else {
                return .offline
            }
        }

        if WCSession.isSupported(), WCSession.default.isReachable {
            return .companion
        }

        if wiFiAvailable {
            return .standalone
        }

        return .offline
    }

    private func switchToMode(_ mode: NetworkMode) async throws {
        // 模式切换逻辑在 Task 7 中实现
    }
}
