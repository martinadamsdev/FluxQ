import SwiftUI

/// 自适应根视图 - 根据平台选择合适的主视图
struct AdaptiveRootView: View {
    var body: some View {
        #if os(macOS)
            Text("macOS 主视图 - 占位")
        #elseif os(iOS)
            Text("iOS 主视图 - 占位")
        #elseif os(watchOS)
            Text("watchOS 主视图 - 占位")
        #endif
    }
}

#Preview("macOS") {
    AdaptiveRootView()
        #if os(macOS)
        .frame(width: 900, height: 600)
        #endif
}

#Preview("iOS") {
    AdaptiveRootView()
}
