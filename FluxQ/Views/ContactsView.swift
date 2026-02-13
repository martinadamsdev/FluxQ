import SwiftUI

struct ContactsView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("暂无联系人")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("通讯录")
        }
    }
}

#Preview {
    ContactsView()
}
