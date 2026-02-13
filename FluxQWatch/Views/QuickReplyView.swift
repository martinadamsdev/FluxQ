// FluxQWatch/Views/QuickReplyView.swift
import SwiftUI
import Observation

@MainActor
@Observable
public class QuickReplyViewModel {
    let service: QuickReplyService
    let lastMessage: String?
    var replies: [QuickReply] = []

    init(service: QuickReplyService, lastMessage: String? = nil) {
        self.service = service
        self.lastMessage = lastMessage
        loadReplies()
    }

    func loadReplies() {
        if let lastMessage {
            replies = service.contextualReplies(for: lastMessage)
        } else {
            replies = service.quickReplies
        }
    }
}

struct QuickReplyView: View {
    @Environment(QuickReplyService.self) private var quickReplyService
    let onSelect: (QuickReply) -> Void

    @State private var viewModel: QuickReplyViewModel?

    var body: some View {
        List {
            if let viewModel {
                ForEach(viewModel.replies) { reply in
                    Button {
                        onSelect(reply)
                    } label: {
                        Text(reply.text)
                    }
                }
            }
        }
        .navigationTitle("快速回复")
        .onAppear {
            viewModel = QuickReplyViewModel(service: quickReplyService)
        }
    }
}
