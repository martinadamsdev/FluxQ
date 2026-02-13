//
//  NetworkTestView.swift
//  FluxQ
//
//  Created by martinadamsdev on 2026/2/13.
//

import SwiftUI
import FluxQServices

struct NetworkTestView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            // 状态指示器
            HStack {
                Circle()
                    .fill(networkManager.discoveredUsers.isEmpty ? Color.gray : Color.green)
                    .frame(width: 12, height: 12)

                Text(networkManager.discoveredUsers.isEmpty ? "暂无用户" : "已发现 \(networkManager.discoveredUsers.count) 个用户")
                    .font(.caption)
            }

            // 控制按钮
            HStack {
                Button("启动网络") {
                    do {
                        try networkManager.start()
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }

                Button("停止网络") {
                    networkManager.stop()
                    errorMessage = nil
                }
            }

            // 错误信息
            if let error = errorMessage {
                Text("错误: \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            // 已发现用户列表
            VStack(alignment: .leading) {
                Text("已发现用户 (\(networkManager.discoveredUsers.count))")
                    .font(.headline)

                if networkManager.discoveredUsers.isEmpty {
                    Text("暂无发现用户")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    List(Array(networkManager.discoveredUsers.values)) { user in
                        VStack(alignment: .leading) {
                            Text(user.nickname)
                                .font(.headline)
                            Text("\(user.hostname) - \(user.ipAddress)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    NetworkTestView()
}
