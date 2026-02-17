import SwiftUI

struct StartChatAction {
    let handler: (UUID) -> Void

    func callAsFunction(_ conversationId: UUID) {
        handler(conversationId)
    }
}

private struct StartChatActionKey: EnvironmentKey {
    static let defaultValue = StartChatAction { _ in }
}

extension EnvironmentValues {
    var startChat: StartChatAction {
        get { self[StartChatActionKey.self] }
        set { self[StartChatActionKey.self] = newValue }
    }
}
