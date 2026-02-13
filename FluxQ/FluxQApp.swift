//
//  FluxQApp.swift
//  FluxQ
//
//  Created by martinadamsdev on 2026/2/13.
//

import SwiftUI
import SwiftData
import FluxQModels
import FluxQUI

@main
struct FluxQApp: App {
    @State private var themeManager = ThemeManager.shared

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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .themedColorScheme(themeManager)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            NavigationCommands()
        }
        #endif
    }
}
