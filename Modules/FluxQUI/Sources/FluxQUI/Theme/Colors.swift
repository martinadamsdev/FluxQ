import SwiftUI

extension Color {
    // 主题色(类似 WeChat 绿)
    public static let fluxqGreen = Color(red: 0.0, green: 0.78, blue: 0.33)

    // 聊天气泡颜色
    public static let fluxqBubbleMe = Color.fluxqGreen
    #if os(iOS) || os(watchOS)
    public static let fluxqBubbleOther = Color(.systemGray5)
    #elseif os(macOS)
    public static let fluxqBubbleOther = Color(nsColor: .controlBackgroundColor)
    #endif

    // 状态颜色
    public static let fluxqOnline = Color.green
    public static let fluxqAway = Color.orange
    public static let fluxqBusy = Color.red
    public static let fluxqOffline = Color.gray
}

extension ShapeStyle where Self == Color {
    public static var fluxqGreen: Color { .fluxqGreen }
    public static var fluxqBubbleMe: Color { .fluxqBubbleMe }
    public static var fluxqBubbleOther: Color { .fluxqBubbleOther }
}
