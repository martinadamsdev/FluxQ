import Foundation

/// 声音播放节流器 — 在指定间隔内只允许触发一次
public struct SoundThrottle: Sendable {
    public let interval: TimeInterval
    public var lastAllowedAt: Date?

    public init(interval: TimeInterval = 3.0) {
        self.interval = interval
    }

    /// 判断当前是否应该播放，若允许则同时记录时间戳
    public mutating func shouldAllow() -> Bool {
        let now = Date()
        guard let last = lastAllowedAt else {
            lastAllowedAt = now
            return true
        }
        if now.timeIntervalSince(last) >= interval {
            lastAllowedAt = now
            return true
        }
        return false
    }
}
