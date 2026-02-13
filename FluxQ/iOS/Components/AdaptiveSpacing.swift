// FluxQ/iOS/Components/AdaptiveSpacing.swift
import CoreGraphics

/// 自适应间距系统 - 根据设备类别提供统一的间距标准
struct AdaptiveSpacing {

    /// 列表项高度
    /// - Parameter category: 设备类别
    /// - Returns: 列表项高度（points）
    static func listItemHeight(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 60
        case .standard:
            return 70
        case .large:
            return 80
        }
    }

    /// 区域间距
    /// - Parameter category: 设备类别
    /// - Returns: 区域间距（points）
    static func sectionSpacing(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 12
        case .standard:
            return 16
        case .large:
            return 20
        }
    }

    /// 水平内边距
    /// - Parameter category: 设备类别
    /// - Returns: 水平内边距（points）
    static func horizontalPadding(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 12
        case .standard:
            return 16
        case .large:
            return 20
        }
    }

    /// 圆角半径
    /// - Parameter category: 设备类别
    /// - Returns: 圆角半径（points）
    static func cornerRadius(for category: iPhoneCategory) -> CGFloat {
        switch category {
        case .compact:
            return 8
        case .standard:
            return 10
        case .large:
            return 12
        }
    }
}
