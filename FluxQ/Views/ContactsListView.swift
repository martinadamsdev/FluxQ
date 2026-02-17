import SwiftUI

/// 联系人列表视图
struct ContactsListView: View {
    @Binding var selection: UUID?

    // TODO: 替换为实际的联系人数据
    private static let mockContacts = [
        (id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!, name: "张三", department: "技术部"),
        (id: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!, name: "李四", department: "产品部"),
        (id: UUID(uuidString: "00000001-0000-0000-0000-000000000003")!, name: "王五", department: "市场部"),
    ]

    var body: some View {
        List(Self.mockContacts, id: \.id, selection: $selection) { contact in
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)

                Text(contact.department)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("通讯录")
    }
}

// 向后兼容初始化器
extension ContactsListView {
    init() {
        self._selection = .constant(nil)
    }
}

#Preview {
    NavigationStack {
        ContactsListView()
    }
}
