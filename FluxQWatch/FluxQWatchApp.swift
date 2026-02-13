// FluxQWatch/FluxQWatchApp.swift
import SwiftUI

@main
struct FluxQWatchApp: App {
    @State private var networkModeManager = NetworkModeManager()
    @State private var connectivityService = WatchConnectivityService()
    @State private var complicationProvider = ComplicationDataProvider()
    @State private var quickReplyService = QuickReplyService()

    var body: some Scene {
        WindowGroup {
            MessageListView()
                .environment(networkModeManager)
                .environment(connectivityService)
                .environment(complicationProvider)
                .environment(quickReplyService)
                .task {
                    networkModeManager.startMonitoring()
                    try? await connectivityService.start()
                }
        }
    }
}
