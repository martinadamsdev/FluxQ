// FluxQWatch/Views/MessageListView.swift
import SwiftUI

struct WatchConversation: Identifiable {
    let id: UUID
    let name: String
    let lastMessage: String
    let unreadCount: Int
    let timestamp: Date
}

struct MessageListView: View {
    @Environment(NetworkModeManager.self) private var networkModeManager
    @Environment(ComplicationDataProvider.self) private var complicationProvider

    // TODO: Replace with SwiftData queries
    private var conversations: [WatchConversation] {
        []
    }

    var body: some View {
        NavigationStack {
            List {
                NetworkStatusView(mode: networkModeManager.currentMode)
                    .listRowBackground(Color.clear)

                if conversations.isEmpty {
                    emptyState
                } else {
                    ForEach(conversations) { conversation in
                        NavigationLink(value: conversation.id) {
                            conversationRow(conversation)
                        }
                    }
                }
            }
            .navigationTitle("FluxQ")
            .navigationDestination(for: UUID.self) { conversationId in
                WatchConversationDetailView(conversationId: conversationId)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "message")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无消息")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .listRowBackground(Color.clear)
    }

    private func conversationRow(_ conversation: WatchConversation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(conversation.lastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue)
                    .clipShape(Capsule())
            }
        }
    }
}
