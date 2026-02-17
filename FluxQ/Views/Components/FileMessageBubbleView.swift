import SwiftUI
import FluxQModels
import FluxQUI

/// 文件消息气泡 -- 显示文件名、大小、传输进度
struct FileMessageBubbleView: View {
    let fileName: String
    let fileSize: Int64
    let progress: Double
    let status: TransferStatus
    let isFromMe: Bool
    let timestamp: Date
    var onCancel: (() -> Void)? = nil

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: fileIcon)
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName)
                            .font(.subheadline)
                            .lineLimit(1)

                        Text(formattedFileSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if status == .transferring {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)

                    if let onCancel {
                        Button("取消", action: onCancel)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if status == .completed {
                    Label("已完成", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if status == .failed {
                    Label("传输失败", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(isFromMe ? Color.fluxqBubbleMe : Color.fluxqBubbleOther)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if !isFromMe { Spacer(minLength: 60) }
        }
    }

    private var fileIcon: String {
        Self.fileIcon(for: fileName)
    }

    private var formattedFileSize: String {
        Self.formattedFileSize(fileSize)
    }

    /// SF Symbol name for a given file name based on extension
    static func fileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "heic": return "photo.fill"
        case "mp4", "mov", "avi": return "film.fill"
        case "zip", "rar", "7z": return "archivebox.fill"
        default: return "doc.fill"
        }
    }

    /// Human-readable file size string
    static func formattedFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview("Transferring") {
    FileMessageBubbleView(
        fileName: "report.pdf",
        fileSize: 5_242_880,
        progress: 0.65,
        status: .transferring,
        isFromMe: true,
        timestamp: Date()
    )
    .padding()
}

#Preview("Completed") {
    FileMessageBubbleView(
        fileName: "photo.jpg",
        fileSize: 2_097_152,
        progress: 1.0,
        status: .completed,
        isFromMe: false,
        timestamp: Date()
    )
    .padding()
}
