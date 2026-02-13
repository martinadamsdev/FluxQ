import SwiftUI

struct TypingIndicatorView: View {
    let username: String
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            Text("\(username) 正在输入")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 5, height: 5)
                        .offset(y: animating ? -3 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear { animating = true }
    }
}

#Preview {
    TypingIndicatorView(username: "Alice")
}
