import SwiftUI

/// iPhone 设备类别 - 根据屏幕高度分类
enum iPhoneCategory: Sendable, Equatable {
    case compact    // iPhone SE, mini (4.7-5.4寸)
    case standard   // iPhone 14/15 (6.1寸)
    case large      // Plus, Pro Max (6.7-6.9寸)

    /// 根据屏幕高度返回对应的设备类别
    static func from(screenHeight: CGFloat) -> iPhoneCategory {
        switch screenHeight {
        case ..<700:
            return .compact
        case 700..<900:
            return .standard
        default:
            return .large
        }
    }

    /// 使用当前设备屏幕高度检测类别
    static var current: iPhoneCategory {
        #if os(iOS)
        let height = UIScreen.main.bounds.height
        return from(screenHeight: height)
        #else
        return .standard
        #endif
    }
}
