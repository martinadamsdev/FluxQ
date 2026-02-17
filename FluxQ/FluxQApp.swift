//
//  FluxQApp.swift
//  FluxQ
//
//  Created by martinadamsdev on 2026/2/13.
//

import SwiftUI
import SwiftData
import FluxQModels
import FluxQServices
import FluxQUI

@main
struct FluxQApp: App {
    @State private var themeManager = ThemeManager.shared
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var heartbeatService = HeartbeatService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Message.self,
            Conversation.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
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

    @State private var lastProcessedMessageCount = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .themedColorScheme(themeManager)
                .environmentObject(networkManager)
                .environmentObject(heartbeatService)
                .onAppear {
                    startNetworkServices()
                }
                .onChange(of: networkManager.receivedMessages.count) { _, newCount in
                    guard newCount > lastProcessedMessageCount else { return }
                    let context = sharedModelContainer.mainContext
                    for i in lastProcessedMessageCount..<newCount {
                        MessageReceiveHandler.handleReceivedMessage(
                            networkManager.receivedMessages[i],
                            in: context
                        )
                    }
                    lastProcessedMessageCount = newCount
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
        do {
            try networkManager.start()
            let nm = networkManager
            heartbeatService.start {
                try await nm.refreshDiscovery()
            }
        } catch {
            print("FluxQApp: 启动网络服务失败 - \(error)")
        }
    }
}
