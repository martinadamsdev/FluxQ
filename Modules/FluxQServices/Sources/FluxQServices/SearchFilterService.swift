import Foundation
import FluxQModels

public enum FilterType: Hashable, Sendable {
    case onlineOnly
    case withAvatar
    case recentlyActive
}

@MainActor
@Observable
public final class SearchFilterService {

    /// Search text matched against nickname, hostname, and group
    public var searchText: String = ""

    /// Active filter conditions (applied with AND logic)
    public var filters: Set<FilterType> = []

    /// Threshold for "recently active" filter (default: 5 minutes)
    public var recentlyActiveThreshold: TimeInterval = 300

    public init() {}

    /// Filter and search users based on current searchText and filters
    public func filterUsers(_ users: [User]) -> [User] {
        var result = users

        // Apply search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { user in
                user.nickname.lowercased().contains(query)
                    || user.hostname.lowercased().contains(query)
                    || (user.group?.lowercased().contains(query) ?? false)
            }
        }

        // Apply filters
        for filter in filters {
            switch filter {
            case .onlineOnly:
                result = result.filter { $0.isOnline }
            case .withAvatar:
                result = result.filter { $0.avatarHash != nil }
            case .recentlyActive:
                let cutoff = Date().addingTimeInterval(-recentlyActiveThreshold)
                result = result.filter { $0.lastSeen >= cutoff }
            }
        }

        return result
    }
}
