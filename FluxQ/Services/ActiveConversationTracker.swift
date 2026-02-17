import Foundation
import Combine

@MainActor
final class ActiveConversationTracker: ObservableObject {
    @Published var activeConversationId: UUID?
}
