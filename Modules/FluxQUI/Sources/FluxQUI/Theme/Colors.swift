import SwiftUI

extension Color {
    // MARK: - 主题色 (Theme Colors)

    /// FluxQ 主品牌色 - 自动适配浅色/深色模式
    /// Light: #00C733, Dark: #00E640
    public static let fluxqGreen = Color("FluxQGreen")

    // MARK: - 聊天气泡 (Chat Bubbles)

    /// 自己发送的消息气泡 - 使用品牌绿色
    public static let fluxqBubbleMe = Color.fluxqGreen

    /// 对方发送的消息气泡 - 自动适配浅色/深色模式
    public static let fluxqBubbleOther: Color = {
        #if os(iOS)
        return Color(.systemGray5)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #elseif os(watchOS)
        return Color("BubbleBackground")
        #endif
    }()

    // MARK: - 状态指示器 (Status Indicators)

    /// 在线状态 - 绿色
    public static let fluxqOnline = Color.green

    /// 离开状态 - 橙色
    public static let fluxqAway = Color.orange

    /// 忙碌状态 - 红色
    public static let fluxqBusy = Color.red

    /// 离线状态 - 灰色
    public static let fluxqOffline = Color.gray

    // MARK: - 语义化颜色 (Semantic Colors)

    /// 主要文本颜色 - 自动适配主题
    public static let fluxqTextPrimary = Color.primary

    /// 次要文本颜色 - 自动适配主题
    public static let fluxqTextSecondary = Color.secondary

    /// 主要背景颜色 - 自动适配主题
    #if os(iOS)
    public static let fluxqBackground = Color(.systemBackground)
    #elseif os(macOS)
    public static let fluxqBackground = Color(nsColor: .windowBackgroundColor)
    #elseif os(watchOS)
    public static let fluxqBackground = Color.black
    #endif

    /// 次要背景颜色 - 自动适配主题
    #if os(iOS)
    public static let fluxqBackgroundSecondary = Color(.secondarySystemBackground)
    #elseif os(macOS)
    public static let fluxqBackgroundSecondary = Color(nsColor: .controlBackgroundColor)
    #elseif os(watchOS)
    public static let fluxqBackgroundSecondary = Color.gray.opacity(0.2)
    #endif
}

extension ShapeStyle where Self == Color {
    public static var fluxqGreen: Color { .fluxqGreen }
    public static var fluxqBubbleMe: Color { .fluxqBubbleMe }
    public static var fluxqBubbleOther: Color { .fluxqBubbleOther }
    public static var fluxqTextPrimary: Color { .fluxqTextPrimary }
    public static var fluxqTextSecondary: Color { .fluxqTextSecondary }
    public static var fluxqBackground: Color { .fluxqBackground }
    public static var fluxqBackgroundSecondary: Color { .fluxqBackgroundSecondary }
}
