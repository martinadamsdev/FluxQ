import SwiftUI

struct DiscoveryView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                Text("暂无在线用户")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("下拉刷新发现局域网用户")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .navigationTitle("发现")
        }
    }
}

#Preview {
    DiscoveryView()
}
