// FluxQTests/iOS/AdaptiveSpacingTests.swift
import Testing
import CoreGraphics
@testable import FluxQ

@Suite("自适应间距系统测试")
struct AdaptiveSpacingTests {

    @Test("列表项高度 - Compact")
    func testListItemHeightCompact() {
        #expect(AdaptiveSpacing.listItemHeight(for: .compact) == 60)
    }

    @Test("列表项高度 - Standard")
    func testListItemHeightStandard() {
        #expect(AdaptiveSpacing.listItemHeight(for: .standard) == 70)
    }

    @Test("列表项高度 - Large")
    func testListItemHeightLarge() {
        #expect(AdaptiveSpacing.listItemHeight(for: .large) == 80)
    }

    @Test("区域间距 - Compact")
    func testSectionSpacingCompact() {
        #expect(AdaptiveSpacing.sectionSpacing(for: .compact) == 12)
    }

    @Test("区域间距 - Standard")
    func testSectionSpacingStandard() {
        #expect(AdaptiveSpacing.sectionSpacing(for: .standard) == 16)
    }

    @Test("区域间距 - Large")
    func testSectionSpacingLarge() {
        #expect(AdaptiveSpacing.sectionSpacing(for: .large) == 20)
    }

    @Test("水平内边距 - Compact")
    func testHorizontalPaddingCompact() {
        #expect(AdaptiveSpacing.horizontalPadding(for: .compact) == 12)
    }

    @Test("水平内边距 - Standard")
    func testHorizontalPaddingStandard() {
        #expect(AdaptiveSpacing.horizontalPadding(for: .standard) == 16)
    }

    @Test("水平内边距 - Large")
    func testHorizontalPaddingLarge() {
        #expect(AdaptiveSpacing.horizontalPadding(for: .large) == 20)
    }

    @Test("圆角半径 - Compact")
    func testCornerRadiusCompact() {
        #expect(AdaptiveSpacing.cornerRadius(for: .compact) == 8)
    }

    @Test("圆角半径 - Standard")
    func testCornerRadiusStandard() {
        #expect(AdaptiveSpacing.cornerRadius(for: .standard) == 10)
    }

    @Test("圆角半径 - Large")
    func testCornerRadiusLarge() {
        #expect(AdaptiveSpacing.cornerRadius(for: .large) == 12)
    }
}
