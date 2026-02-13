import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("个人信息") {
                    HStack {
                        Text("昵称")
                        Spacer()
                        Text("未设置")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("部门")
                        Spacer()
                        Text("未设置")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("状态") {
                    Picker("当前状态", selection: .constant("在线")) {
                        Text("在线").tag("在线")
                        Text("离开").tag("离开")
                        Text("忙碌").tag("忙碌")
                    }
                }
            }
            .navigationTitle("我")
        }
    }
}

#Preview {
    SettingsView()
}
