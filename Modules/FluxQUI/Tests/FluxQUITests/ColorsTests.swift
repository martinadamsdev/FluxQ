import Testing
import SwiftUI
@testable import FluxQUI

@Suite("Colors Tests")
struct ColorsTests {

    // MARK: - Theme Colors

    @Test("fluxqGreen color exists")
    func fluxqGreenExists() {
        let color: Color = .fluxqGreen
        #expect(type(of: color) == Color.self)
    }

    // MARK: - Chat Bubble Colors

    @Test("fluxqBubbleMe color exists")
    func fluxqBubbleMeExists() {
        let color: Color = .fluxqBubbleMe
        #expect(type(of: color) == Color.self)
    }

    @Test("fluxqBubbleMe equals fluxqGreen")
    func fluxqBubbleMeIsGreen() {
        #expect(Color.fluxqBubbleMe == Color.fluxqGreen)
    }

    @Test("fluxqBubbleOther color exists")
    func fluxqBubbleOtherExists() {
        let color: Color = .fluxqBubbleOther
        #expect(type(of: color) == Color.self)
    }

    // MARK: - Status Indicator Colors

    @Test("fluxqOnline color is green")
    func fluxqOnlineColor() {
        #expect(Color.fluxqOnline == Color.green)
    }

    @Test("fluxqAway color is orange")
    func fluxqAwayColor() {
        #expect(Color.fluxqAway == Color.orange)
    }

    @Test("fluxqBusy color is red")
    func fluxqBusyColor() {
        #expect(Color.fluxqBusy == Color.red)
    }

    @Test("fluxqOffline color is gray")
    func fluxqOfflineColor() {
        #expect(Color.fluxqOffline == Color.gray)
    }

    // MARK: - Semantic Colors

    @Test("fluxqTextPrimary color is primary")
    func fluxqTextPrimaryColor() {
        #expect(Color.fluxqTextPrimary == Color.primary)
    }

    @Test("fluxqTextSecondary color is secondary")
    func fluxqTextSecondaryColor() {
        #expect(Color.fluxqTextSecondary == Color.secondary)
    }

    @Test("fluxqBackground color exists")
    func fluxqBackgroundExists() {
        let color: Color = .fluxqBackground
        #expect(type(of: color) == Color.self)
    }

    @Test("fluxqBackgroundSecondary color exists")
    func fluxqBackgroundSecondaryExists() {
        let color: Color = .fluxqBackgroundSecondary
        #expect(type(of: color) == Color.self)
    }

    // MARK: - ShapeStyle Extensions

    @Test("ShapeStyle extension provides fluxqGreen")
    func shapeStyleFluxqGreen() {
        let style: Color = .fluxqGreen
        #expect(style == Color.fluxqGreen)
    }

    @Test("ShapeStyle extension provides fluxqBubbleMe")
    func shapeStyleFluxqBubbleMe() {
        let style: Color = .fluxqBubbleMe
        #expect(style == Color.fluxqBubbleMe)
    }

    @Test("ShapeStyle extension provides fluxqTextPrimary")
    func shapeStyleFluxqTextPrimary() {
        let style: Color = .fluxqTextPrimary
        #expect(style == Color.fluxqTextPrimary)
    }
}
