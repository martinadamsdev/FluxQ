import Foundation
import WatchConnectivity
import Observation

@MainActor
@Observable
public class WatchConnectivityService: NSObject, WCSessionDelegate {
    public private(set) var isReachable: Bool = false
    public private(set) var lastSyncTime: Date?

    private let testMode: Bool
    var mockIsReachable: Bool = false
    var mockSentMessages: [[String: Any]] = []

    public init(testMode: Bool = false) {
        self.testMode = testMode
        super.init()

        if !testMode, WCSession.isSupported() {
            WCSession.default.delegate = self
        }
    }

    public func start() async throws {
        guard !testMode else { return }
        guard WCSession.isSupported() else {
            throw WatchError.watchConnectivityNotSupported
        }
        WCSession.default.activate()
    }

    public func stop() {
        // 清理资源
    }

    public func sendMessage(to userId: String, content: String) async throws {
        if testMode {
            guard mockIsReachable else {
                throw WatchError.iPhoneNotReachable
            }

            mockSentMessages.append([
                "action": "sendMessage",
                "recipientId": userId,
                "content": content
            ])
            return
        }

        guard WCSession.default.isReachable else {
            throw WatchError.iPhoneNotReachable
        }

        let payload: [String: Any] = [
            "action": "sendMessage",
            "recipientId": userId,
            "content": content,
            "timestamp": Date().timeIntervalSince1970
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            WCSession.default.sendMessage(payload, replyHandler: { reply in
                if let error = reply["error"] as? String {
                    continuation.resume(throwing: WatchError.iPhoneSendFailed(error))
                } else {
                    continuation.resume(returning: ())
                }
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            guard let action = message["action"] as? String else { return }

            switch action {
            case "newMessage":
                try? await handleNewMessage(message)
            case "messageRecalled":
                try? await handleMessageRecalled(message)
            default:
                break
            }
        }
    }

    private func handleNewMessage(_ payload: [String: Any]) async throws {
        // TODO: 保存到 SwiftData
    }

    private func handleMessageRecalled(_ payload: [String: Any]) async throws {
        // TODO: 更新 SwiftData
    }

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }
}

public enum WatchError: Error, LocalizedError, Equatable {
    case watchConnectivityNotSupported
    case iPhoneNotReachable
    case iPhoneSendFailed(String)

    public var errorDescription: String? {
        switch self {
        case .watchConnectivityNotSupported:
            return "当前设备不支持 Watch Connectivity"
        case .iPhoneNotReachable:
            return "iPhone 不在附近或未连接"
        case .iPhoneSendFailed(let reason):
            return "通过 iPhone 发送失败: \(reason)"
        }
    }
}
