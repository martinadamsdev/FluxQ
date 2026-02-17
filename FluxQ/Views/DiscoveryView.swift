import SwiftUI
import SwiftData
import FluxQServices
import FluxQModels

struct DiscoveryView: View {
    @EnvironmentObject private var networkManager: NetworkManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.startChat) private var startChat
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

                        Text(networkManager.networkStatus)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    List(filteredUsers) { user in
                        Button {
                            handleUserTap(user)
                        } label: {
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
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("发现")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        try? networkManager.refreshDiscovery()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func handleUserTap(_ user: User) {
        guard let discoveredUser = networkManager.discoveredUsers.values.first(where: { $0.id == user.id }) else {
            return
        }

        let conversationId = ConversationService.findOrCreateConversation(
            hostname: discoveredUser.hostname,
            senderName: discoveredUser.senderName,
            nickname: discoveredUser.nickname,
            ipAddress: discoveredUser.ipAddress,
            port: discoveredUser.port,
            group: discoveredUser.group,
            in: modelContext
        )

        startChat(conversationId)
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
