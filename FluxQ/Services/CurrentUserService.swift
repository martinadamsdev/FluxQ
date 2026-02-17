import Foundation
import SwiftData
import FluxQModels
import FluxQServices

enum CurrentUserService {

    /// 获取或创建当前用户的 User 对象
    static func currentUser(
        networkManager: NetworkManager,
        in context: ModelContext
    ) -> User {
        let hostname = hostName()
        let deviceName = deviceName()
        let localIP = "127.0.0.1"

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate {
                $0.hostname == hostname && $0.ipAddress == localIP
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.isOnline = true
            existing.lastSeen = Date()
            return existing
        }

        let user = User(
            nickname: deviceName,
            hostname: hostname,
            ipAddress: localIP,
            port: 2425,
            status: .online,
            isOnline: true
        )
        context.insert(user)
        try? context.save()
        return user
    }

    private static func deviceName() -> String {
        #if os(macOS)
        return Host.current().localizedName ?? "Unknown"
        #elseif os(iOS)
        return UIDevice.current.name
        #elseif os(watchOS)
        return WKInterfaceDevice.current().name
        #else
        return "Unknown"
        #endif
    }

    private static func hostName() -> String {
        #if os(macOS)
        return Host.current().name ?? "Unknown"
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }
}
