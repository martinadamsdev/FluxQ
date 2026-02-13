import SwiftUI
import FluxQServices
import FluxQModels

struct DiscoveryView: View {
    @StateObject private var networkManager = NetworkManager()
    @StateObject private var heartbeatService = HeartbeatService()
    @State private var searchService = SearchFilterService()

    private var filteredUsers: [User] {
        let users = networkManager.discoveredUsers.values.map { $0.toUser() }
        return searchService.filterUsers(users)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("搜索用户", text: $searchService.searchText)
                        .textFieldStyle(.plain)

                    if !searchService.searchText.isEmpty {
                        Button {
                            searchService.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                #if os(iOS)
                .background(Color(.systemGray6))
                #else
                .background(Color.secondary.opacity(0.1))
                #endif

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "仅在线",
                            isSelected: searchService.filters.contains(.onlineOnly)
                        ) {
                            toggleFilter(.onlineOnly)
                        }

                        FilterChip(
                            title: "有头像",
                            isSelected: searchService.filters.contains(.withAvatar)
                        ) {
                            toggleFilter(.withAvatar)
                        }

                        FilterChip(
                            title: "最近活跃",
                            isSelected: searchService.filters.contains(.recentlyActive)
                        ) {
                            toggleFilter(.recentlyActive)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // User list
                if filteredUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text(networkManager.discoveredUsers.isEmpty ? "暂无发现用户" : "无匹配用户")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text(networkManager.discoveredUsers.isEmpty ? "正在搜索局域网用户..." : "尝试调整搜索或过滤条件")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else {
                    List(filteredUsers) { user in
                        HStack(spacing: 12) {
                            UserAvatarView(avatarData: user.avatarData, size: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.nickname)
                                    .font(.headline)

                                HStack {
                                    Text(user.hostname)
                                    Text("·")
                                    Text(user.ipAddress)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if let group = user.group {
                                    Text(group)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            if user.isOnline {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
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
                heartbeatService.stop()
            }
        }
    }

    private func toggleFilter(_ filter: FilterType) {
        if searchService.filters.contains(filter) {
            searchService.filters.remove(filter)
        } else {
            searchService.filters.insert(filter)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                #if os(iOS)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                #else
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                #endif
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DiscoveryView()
}
