// FluxQWatch/Views/NetworkStatusView.swift
import SwiftUI

struct NetworkStatusView: View {
    let mode: NetworkModeManager.NetworkMode

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch mode {
        case .companion: return .green
        case .standalone: return .blue
        case .offline: return .red
        }
    }

    private var statusText: String {
        switch mode {
        case .companion: return "已连接 iPhone"
        case .standalone: return "独立模式"
        case .offline: return "离线"
        }
    }
}
