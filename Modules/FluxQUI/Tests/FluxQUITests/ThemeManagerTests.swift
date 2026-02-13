import Testing
import SwiftUI
@testable import FluxQUI

@Suite("ThemeManager Tests", .serialized)
struct ThemeManagerTests {

    @Test("Shared singleton instance exists")
    func sharedInstance() {
        let manager = ThemeManager.shared
        #expect(manager === ThemeManager.shared)
    }

    @Test("Default colorScheme is nil")
    func defaultColorScheme() {
        let manager = ThemeManager.shared
        // Reset to default state
        manager.setColorScheme(nil)
        #expect(manager.colorScheme == nil)
    }

    @Test("setColorScheme to dark")
    func setDarkScheme() {
        let manager = ThemeManager.shared
        manager.setColorScheme(.dark)
        #expect(manager.colorScheme == .dark)
        // Clean up
        manager.setColorScheme(nil)
    }

    @Test("setColorScheme to light")
    func setLightScheme() {
        let manager = ThemeManager.shared
        manager.setColorScheme(.light)
        #expect(manager.colorScheme == .light)
        // Clean up
        manager.setColorScheme(nil)
    }

    @Test("setColorScheme to nil clears scheme")
    func setNilScheme() {
        let manager = ThemeManager.shared
        manager.setColorScheme(.dark)
        #expect(manager.colorScheme == .dark)

        manager.setColorScheme(nil)
        #expect(manager.colorScheme == nil)
    }

    @Test("setColorScheme switches between schemes")
    func switchSchemes() {
        let manager = ThemeManager.shared

        manager.setColorScheme(.light)
        #expect(manager.colorScheme == .light)

        manager.setColorScheme(.dark)
        #expect(manager.colorScheme == .dark)

        manager.setColorScheme(.light)
        #expect(manager.colorScheme == .light)

        // Clean up
        manager.setColorScheme(nil)
    }
}
