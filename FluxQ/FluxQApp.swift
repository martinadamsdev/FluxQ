//
//  FluxQApp.swift
//  FluxQ
//
//  Created by martinadamsdev on 2026/2/13.
//

import SwiftUI
import SwiftData
import UserNotifications
import FluxQModels
import FluxQServices
import FluxQUI

@main
struct FluxQApp: App {
    @State private var themeManager = ThemeManager.shared
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var heartbeatService = HeartbeatService()
    @StateObject private var conversationTracker = ActiveConversationTracker()
    private let notificationDelegate = NotificationDelegate()

    static let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Message.self,
            Conversation.self,
            FileTransfer.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            if isUITesting {
                seedUITestData(in: container.mainContext)
            }
            return container
        } catch {
            // Schema migration failed — delete old store and retry
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let storePath = appSupport.appendingPathComponent("default.store").path
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(atPath: storePath + suffix)
            }

            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Could not create ModelContainer after reset: \(error)")
            }
        }
    }()

    /// Seed test data for XCUITests — creates conversations and messages in-memory
    @MainActor
    private static func seedUITestData(in context: ModelContext) {
        // Current user (local)
        let currentUser = User(
            nickname: "我",
            hostname: ProcessInfo.processInfo.hostName,
            ipAddress: "127.0.0.1",
            port: 2425,
            group: nil,
            status: .online,
            isOnline: true
        )
        context.insert(currentUser)

        // Remote user: Alice
        let alice = User(
            nickname: "Alice",
            hostname: "alice-mac",
            ipAddress: "192.168.1.10",
            port: 2425,
            group: nil,
            status: .online,
            isOnline: true
        )
        context.insert(alice)

        // Remote user: Bob (no messages)
        let bob = User(
            nickname: "Bob",
            hostname: "bob-mac",
            ipAddress: "192.168.1.20",
            port: 2425,
            group: nil,
            status: .online,
            isOnline: true
        )
        context.insert(bob)

        // Conversation with Alice (has messages)
        let aliceConv = Conversation(
            type: .private,
            participantIDs: [alice.id]
        )
        aliceConv.participants = [alice]
        context.insert(aliceConv)

        let msg1 = Message(
            conversationID: aliceConv.id,
            senderID: alice.id,
            content: "你好，我是 Alice！",
            timestamp: Date().addingTimeInterval(-120),
            status: .delivered
        )
        let msg2 = Message(
            conversationID: aliceConv.id,
            senderID: currentUser.id,
            content: "你好 Alice，很高兴认识你",
            timestamp: Date().addingTimeInterval(-60),
            status: .sent
        )
        let msg3 = Message(
            conversationID: aliceConv.id,
            senderID: alice.id,
            content: "这是一条测试消息",
            timestamp: Date(),
            status: .delivered
        )
        context.insert(msg1)
        context.insert(msg2)
        context.insert(msg3)

        // 显式建立 SwiftData 关系（Message 无反向 @Relationship）
        aliceConv.messages = [msg1, msg2, msg3]
        aliceConv.lastMessageTimestamp = Date()
        aliceConv.unreadCount = 2

        // Conversation with Bob (empty, for testing empty state)
        let bobConv = Conversation(
            type: .private,
            participantIDs: [bob.id]
        )
        bobConv.participants = [bob]
        bobConv.lastMessageTimestamp = Date().addingTimeInterval(-300)
        context.insert(bobConv)

        try? context.save()
    }

    @State private var processedMessageIndices = Set<Int>()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .themedColorScheme(themeManager)
                .environmentObject(networkManager)
                .environmentObject(heartbeatService)
                .environmentObject(conversationTracker)
                .onAppear {
                    if !FluxQApp.isUITesting {
                        startNetworkServices()
                    }
                }
                .onChange(of: networkManager.receivedMessages.count) { _, newCount in
                    let context = sharedModelContainer.mainContext
                    for i in 0..<newCount where !processedMessageIndices.contains(i) {
                        processedMessageIndices.insert(i)
                        let received = networkManager.receivedMessages[i]
                        MessageReceiveHandler.handleReceivedMessage(received, in: context)
                        handleNotification(for: received)
                    }
                }
                .onChange(of: networkManager.receivedRecalls.count) { _, _ in
                    if let lastRecall = networkManager.receivedRecalls.last {
                        let context = sharedModelContainer.mainContext
                        MessageReceiveHandler.handleRecallCommand(
                            messageIDString: lastRecall,
                            in: context
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            NavigationCommands()
        }
        #endif
    }

    private func startNetworkServices() {
        // 设置通知委托
        UNUserNotificationCenter.current().delegate = notificationDelegate
        notificationDelegate.onNotificationTapped = { conversationId in
            NotificationCenter.default.post(
                name: .navigateToConversation,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }

        // 请求通知权限
        NotificationService.shared.requestPermission()

        do {
            try networkManager.start()
            let nm = networkManager
            heartbeatService.start {
                try nm.refreshDiscovery()
            }
        } catch {
            print("FluxQApp: 启动网络服务失败 - \(error)")
        }
    }

    private func handleNotification(for received: ReceivedMessage) {
        let isSoundEnabled = NotificationHandler.isSoundEnabled()
        let soundName = NotificationHandler.soundName()

        // 查找该消息对应的对话 ID
        let hostname = received.hostname
        let ipAddress = received.fromHost
        let context = sharedModelContainer.mainContext
        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.hostname == hostname && $0.ipAddress == ipAddress }
        )
        guard let sender = try? context.fetch(userDescriptor).first else { return }

        // SwiftData #Predicate 不支持 .contains on Array，使用内存过滤
        let allConversations = (try? context.fetch(FetchDescriptor<Conversation>())) ?? []
        let conversationId = allConversations.first {
            $0.type == .private && $0.participantIDs.contains(sender.id)
        }?.id

        // 纯逻辑决策
        #if os(macOS)
        let isAppActive = NSApplication.shared.isActive
        #else
        let isAppActive = true
        #endif

        let action = NotificationHandler.determineAction(
            conversationId: conversationId,
            activeConversationId: conversationTracker.activeConversationId,
            isSoundEnabled: isSoundEnabled,
            isAppActive: isAppActive
        )

        if action.shouldPlaySound {
            SoundManager.shared.play(soundName: soundName)
        }

        if action.shouldSendNotification, let conversationId {
            NotificationService.shared.sendNotification(
                title: received.senderName,
                body: received.content,
                conversationId: conversationId,
                soundName: soundName
            )
        }
    }
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onNotificationTapped: ((UUID) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let conversationId = Self.parseConversationId(from: userInfo) {
            Task { @MainActor in
                onNotificationTapped?(conversationId)
            }
        }
        completionHandler()
    }

    /// 从通知 userInfo 中解析 conversationId UUID
    static func parseConversationId(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let idString = userInfo["conversationId"] as? String else { return nil }
        return UUID(uuidString: idString)
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let navigateToConversation = Notification.Name("navigateToConversation")
}
