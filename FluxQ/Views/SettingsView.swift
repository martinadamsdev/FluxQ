import SwiftUI
import FluxQUI

struct SettingsView: View {
    @State private var selectedTheme: String = "系统"

    // 通知设置
    @AppStorage("notification.soundEnabled") private var soundEnabled = true
    @AppStorage("notification.soundName") private var soundName = "Glass"

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

                Section("通知") {
                    Toggle("消息提示音", isOn: $soundEnabled)

                    if soundEnabled {
                        Picker("提示音", selection: $soundName) {
                            ForEach(SoundManager.availableSystemSounds, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .onChange(of: soundName) { _, newValue in
                            SoundManager.shared.play(soundName: newValue, force: true)
                        }
                    }
                }

                Section("外观") {
                    Picker("主题", selection: $selectedTheme) {
                        Text("浅色").tag("浅色")
                        Text("深色").tag("深色")
                        Text("系统").tag("系统")
                    }
                    .onChange(of: selectedTheme) { _, newValue in
                        switch newValue {
                        case "浅色":
                            ThemeManager.shared.setColorScheme(.light)
                        case "深色":
                            ThemeManager.shared.setColorScheme(.dark)
                        default:
                            ThemeManager.shared.setColorScheme(nil)
                        }
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
