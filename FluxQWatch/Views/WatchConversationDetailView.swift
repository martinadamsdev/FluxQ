// FluxQWatch/Views/WatchConversationDetailView.swift
import SwiftUI

struct WatchConversationDetailView: View {
    let conversationId: UUID
    @Environment(QuickReplyService.self) private var quickReplyService

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                Text("会话详情")
                    .font(.headline)
                Text("会话 ID: \(conversationId.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                NavigationLink {
                    QuickReplyView { reply in
                        // TODO: 发送快速回复
                    }
                } label: {
                    Image(systemName: "text.bubble")
                }
            }
        }
    }
}
