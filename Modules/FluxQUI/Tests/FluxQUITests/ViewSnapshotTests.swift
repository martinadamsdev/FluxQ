import Testing
import SwiftUI
@testable import FluxQUI

// MARK: - 测试用辅助 View

/// 模拟 UserAvatarView 的占位符逻辑，验证 FluxQUI 颜色在头像场景中的正确应用
private struct TestAvatarView: View {
    let avatarData: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let avatarData, let image = makeImage(from: avatarData) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.fluxqTextSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func makeImage(from data: Data) -> Image? {
        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}

/// 模拟 DiscoveryView 空状态，验证 FluxQUI 颜色和主题集成
private struct TestDiscoveryEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 60))
                .foregroundStyle(Color.fluxqTextSecondary)

            Text("暂无发现用户")
                .font(.title2)
                .foregroundStyle(Color.fluxqTextSecondary)

            Text("正在搜索局域网用户...")
                .font(.subheadline)
                .foregroundStyle(Color.fluxqTextSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluxqBackground)
    }
}

// MARK: - UserAvatarView 结构验证测试

@Suite("UserAvatarView 结构验证")
struct UserAvatarViewSnapshotTests {

    @Test("无头像数据时创建占位符 View 不崩溃")
    func avatarWithNilData() {
        let view = TestAvatarView(avatarData: nil, size: 40)
        #expect(view.avatarData == nil)
        #expect(view.size == 40)
        _ = view.body
    }

    @Test("有无效头像数据时 View 不崩溃")
    func avatarWithInvalidData() {
        let invalidData = Data([0x00, 0x01, 0x02])
        let view = TestAvatarView(avatarData: invalidData, size: 40)
        #expect(view.avatarData != nil)
        _ = view.body
    }

    @Test("有效 PNG 头像数据时 View 不崩溃")
    func avatarWithValidImageData() {
        let imageData = createMinimalPNGData()
        let view = TestAvatarView(avatarData: imageData, size: 40)
        #expect(view.avatarData != nil)
        _ = view.body
    }

    @Test("不同 size 参数正确应用")
    func avatarSizeVariations() {
        let sizes: [CGFloat] = [20, 40, 60, 80, 120]
        for size in sizes {
            let view = TestAvatarView(avatarData: nil, size: size)
            #expect(view.size == size)
            _ = view.body
        }
    }

    @Test("size 为零时 View 不崩溃")
    func avatarZeroSize() {
        let view = TestAvatarView(avatarData: nil, size: 0)
        #expect(view.size == 0)
        _ = view.body
    }

    /// 创建最小有效 PNG 数据 (1x1 红色像素)
    private func createMinimalPNGData() -> Data {
        #if canImport(AppKit)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return pngData
        #elseif canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.pngData() ?? Data()
        #else
        return Data()
        #endif
    }
}

// MARK: - DiscoveryView 结构验证测试

@Suite("DiscoveryView 结构验证")
struct DiscoveryViewSnapshotTests {

    @Test("空状态 View 正确初始化不崩溃")
    func emptyStateViewCreation() {
        let view = TestDiscoveryEmptyView()
        _ = view.body
    }

    @Test("空状态 View 使用 FluxQUI 颜色不崩溃")
    func emptyStateUsesFluxQColors() {
        // 验证 FluxQUI 颜色在 View 上下文中可正常访问
        let _ = Color.fluxqTextSecondary
        let _ = Color.fluxqBackground
        let view = TestDiscoveryEmptyView()
        _ = view.body
    }
}

// MARK: - ThemeManager View 集成测试

@Suite("ThemeManager View 集成", .serialized)
struct ThemeManagerViewIntegrationTests {

    @Test("themedColorScheme modifier 不崩溃")
    func themedColorSchemeModifier() {
        let manager = ThemeManager.shared
        manager.setColorScheme(nil)

        let view = Text("Test").themedColorScheme(manager)
        _ = view
    }

    @Test("themedColorScheme 使用默认 shared 实例")
    func themedColorSchemeDefaultManager() {
        let manager = ThemeManager.shared
        manager.setColorScheme(nil)

        let view = Text("Test").themedColorScheme()
        _ = view
    }

    @Test("切换到 dark 模式后 View 不崩溃")
    func darkModeViewCreation() {
        let manager = ThemeManager.shared
        manager.setColorScheme(.dark)

        let view = VStack {
            Text("Dark mode")
                .foregroundStyle(Color.fluxqTextPrimary)
        }
        .background(Color.fluxqBackground)
        .themedColorScheme(manager)

        _ = view

        // 恢复
        manager.setColorScheme(nil)
    }

    @Test("切换到 light 模式后 View 不崩溃")
    func lightModeViewCreation() {
        let manager = ThemeManager.shared
        manager.setColorScheme(.light)

        let view = VStack {
            Text("Light mode")
                .foregroundStyle(Color.fluxqTextPrimary)
        }
        .background(Color.fluxqBackground)
        .themedColorScheme(manager)

        _ = view

        // 恢复
        manager.setColorScheme(nil)
    }

    @Test("连续切换主题不崩溃")
    func rapidThemeSwitching() {
        let manager = ThemeManager.shared

        for _ in 0..<10 {
            manager.setColorScheme(.dark)
            let darkView = Text("Test")
                .foregroundStyle(Color.fluxqTextPrimary)
                .background(Color.fluxqBackground)
                .themedColorScheme(manager)
            _ = darkView

            manager.setColorScheme(.light)
            let lightView = Text("Test")
                .foregroundStyle(Color.fluxqTextPrimary)
                .background(Color.fluxqBackground)
                .themedColorScheme(manager)
            _ = lightView
        }

        // 恢复
        manager.setColorScheme(nil)
    }

    @Test("所有 FluxQUI 颜色在 View 上下文中可用")
    func allColorsAccessibleInView() {
        let view = VStack {
            Text("Green").foregroundStyle(Color.fluxqGreen)
            Text("BubbleMe").foregroundStyle(Color.fluxqBubbleMe)
            Text("BubbleOther").foregroundStyle(Color.fluxqBubbleOther)
            Text("Online").foregroundStyle(Color.fluxqOnline)
            Text("Away").foregroundStyle(Color.fluxqAway)
            Text("Busy").foregroundStyle(Color.fluxqBusy)
            Text("Offline").foregroundStyle(Color.fluxqOffline)
            Text("Primary").foregroundStyle(Color.fluxqTextPrimary)
            Text("Secondary").foregroundStyle(Color.fluxqTextSecondary)
        }
        .background(Color.fluxqBackground)

        _ = view
    }

    @Test("ShapeStyle 扩展在 View 上下文中可用")
    func shapeStyleExtensionsInView() {
        let view = VStack {
            Rectangle().fill(.fluxqGreen)
            Rectangle().fill(.fluxqBubbleMe)
            Rectangle().fill(.fluxqBubbleOther)
            Rectangle().fill(.fluxqTextPrimary)
            Rectangle().fill(.fluxqTextSecondary)
            Rectangle().fill(.fluxqBackground)
            Rectangle().fill(.fluxqBackgroundSecondary)
        }

        _ = view
    }
}
