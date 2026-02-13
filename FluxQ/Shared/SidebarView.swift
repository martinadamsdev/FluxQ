import SwiftUI

/// 侧边栏视图 - macOS 和 iPad 横屏共享
struct SidebarView: View {
    @Binding var selection: AppNavigationItem

    var body: some View {
        List {
            ForEach(AppNavigationItem.allCases) { item in
                Button {
                    selection = item
                } label: {
                    Label(item.rawValue, systemImage: item.systemImage)
                }
                .listItemTint(selection == item ? .accentColor : nil)
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
                .listRowBackground(
                    selection == item
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                )
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FluxQ")
        #if os(macOS)
        .frame(minWidth: 180)
        #endif
    }
}

#Preview {
    NavigationSplitView {
        SidebarView(selection: .constant(.messages))
    } detail: {
        Text("详情")
    }
    #if os(macOS)
    .frame(width: 900, height: 600)
    #endif
}
