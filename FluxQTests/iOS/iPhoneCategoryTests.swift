// FluxQTests/iOS/iPhoneCategoryTests.swift
import Testing
import CoreGraphics
@testable import FluxQ

@Suite("iPhone 设备分类测试")
struct iPhoneCategoryTests {

    @Test("Compact 设备检测 - iPhone SE")
    func testCompactDevice() {
        let height: CGFloat = 650
        #expect(iPhoneCategory.from(screenHeight: height) == .compact)
    }

    @Test("Compact 边界测试 - 699")
    func testCompactBoundary() {
        let height: CGFloat = 699
        #expect(iPhoneCategory.from(screenHeight: height) == .compact)
    }

    @Test("Standard 设备检测 - iPhone 15")
    func testStandardDevice() {
        let height: CGFloat = 850
        #expect(iPhoneCategory.from(screenHeight: height) == .standard)
    }

    @Test("Standard 下边界测试 - 700")
    func testStandardLowerBoundary() {
        let height: CGFloat = 700
        #expect(iPhoneCategory.from(screenHeight: height) == .standard)
    }

    @Test("Standard 上边界测试 - 899")
    func testStandardUpperBoundary() {
        let height: CGFloat = 899
        #expect(iPhoneCategory.from(screenHeight: height) == .standard)
    }

    @Test("Large 设备检测 - iPhone Pro Max")
    func testLargeDevice() {
        let height: CGFloat = 950
        #expect(iPhoneCategory.from(screenHeight: height) == .large)
    }

    @Test("Large 边界测试 - 900")
    func testLargeBoundary() {
        let height: CGFloat = 900
        #expect(iPhoneCategory.from(screenHeight: height) == .large)
    }
}
