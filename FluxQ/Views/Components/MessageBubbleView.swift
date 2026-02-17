import SwiftUI
import FluxQModels
import FluxQUI

struct MessageBubbleView: View {
    let content: String
    let isFromMe: Bool
    let timestamp: Date
    let status: MessageStatus
    let isRecalled: Bool
    var onResend: (() -> Void)? = nil

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                if isRecalled {
                    Text("消息已撤回")
                        .italic()
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    Text(content)
                        .foregroundStyle(isFromMe ? .white : .fluxqTextPrimary)
                }

                HStack(spacing: 4) {
                    Text(timestamp, style: .time)
                        .font(.caption2)
                    if isFromMe {
                        MessageStatusIcon(status: status)
                    }
                    if status == .failed, let onResend {
                        Button(action: onResend) {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, isRecalled ? 4 : 12)
            .padding(.vertical, isRecalled ? 4 : 8)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: isRecalled ? 8 : 16))

            if !isFromMe { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if isRecalled {
            Color.clear
        } else if isFromMe {
            Color.fluxqBubbleMe
        } else {
            Color.fluxqBubbleOther
        }
    }
}

// MARK: - Message Status Icon

struct MessageStatusIcon: View {
    let status: MessageStatus

    var body: some View {
        switch status {
        case .pending:
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
        case .sending:
            Image(systemName: "clock")
                .font(.caption2)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .font(.caption2)
        case .read:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.fluxqGreen)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}

#Preview("From Me") {
    MessageBubbleView(
        content: "Hello, this is a test message!",
        isFromMe: true,
        timestamp: Date(),
        status: .sent,
        isRecalled: false
    )
    .padding()
}

#Preview("From Other") {
    MessageBubbleView(
        content: "Hi! Nice to hear from you.",
        isFromMe: false,
        timestamp: Date(),
        status: .delivered,
        isRecalled: false
    )
    .padding()
}

#Preview("Recalled") {
    MessageBubbleView(
        content: "This was recalled",
        isFromMe: true,
        timestamp: Date(),
        status: .sent,
        isRecalled: true
    )
    .padding()
}
