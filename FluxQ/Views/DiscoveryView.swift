import SwiftUI
import FluxQServices

struct DiscoveryView: View {
    @StateObject private var networkManager = NetworkManager()

    var body: some View {
        NavigationStack {
            VStack {
                if networkManager.discoveredUsers.isEmpty {
                    // 空状态
                    VStack {
                        Image(systemName: "globe")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("暂无发现用户")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("正在搜索局域网用户...")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    // 用户列表
                    List(Array(networkManager.discoveredUsers.values)) { user in
                        VStack(alignment: .leading) {
                            Text(user.nickname)
                                .font(.headline)

                            HStack {
                                Text(user.hostname)
                                Text("·")
                                Text(user.ipAddress)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("发现")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        networkManager.stop()
                        do {
                            try networkManager.start()
                        } catch {
                            print("启动网络失败: \(error)")
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                do {
                    try networkManager.start()
                } catch {
                    print("启动网络失败: \(error)")
                }
            }
            .onDisappear {
                networkManager.stop()
            }
        }
    }
}

#Preview {
    DiscoveryView()
}
