import SwiftUI

/// 联系人详情视图
struct ContactDetailView: View {
    let contactId: UUID?

    // TODO: 实际的联系人数据查询
    private var mockContact: (name: String, department: String)? {
        guard contactId != nil else { return nil }
        return (name: "张三", department: "技术部")
    }

    var body: some View {
        if let contact = mockContact {
            VStack(spacing: 24) {
                // 头像
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.blue)

                // 基本信息
                VStack(spacing: 8) {
                    Text(contact.name)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(contact.department)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // 操作按钮
                VStack(spacing: 12) {
                    Button(action: {
                        // TODO: 发送消息
                    }) {
                        Label("发送消息", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        // TODO: 查看资料
                    }) {
                        Label("查看资料", systemImage: "info.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("联系人详情")
        } else {
            ContentUnavailableView(
                "选择一个联系人",
                systemImage: "person.fill",
                description: Text("从左侧列表中选择一个联系人以查看详情")
            )
        }
    }
}

#Preview("已选中") {
    NavigationStack {
        ContactDetailView(contactId: UUID())
    }
}

#Preview("未选中") {
    NavigationStack {
        ContactDetailView(contactId: nil)
    }
}
