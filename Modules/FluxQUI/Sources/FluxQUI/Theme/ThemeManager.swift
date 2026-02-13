import SwiftUI

@Observable
public final class ThemeManager {
    public static let shared = ThemeManager()

    public var colorScheme: ColorScheme?

    private init() {}

    public func setColorScheme(_ scheme: ColorScheme?) {
        self.colorScheme = scheme
    }
}

// View Extension for easy theme access
extension View {
    public func themedColorScheme(_ manager: ThemeManager = .shared) -> some View {
        self.preferredColorScheme(manager.colorScheme)
    }
}
