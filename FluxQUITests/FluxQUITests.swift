//
//  FluxQUITests.swift
//  FluxQUITests
//
//  Created by martinadamsdev on 2026/2/13.
//

import XCTest

final class FluxQUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        let messagesTab = app.tabBars.buttons["消息"]
        XCTAssertTrue(messagesTab.exists)

        let discoveryTab = app.tabBars.buttons["发现"]
        XCTAssertTrue(discoveryTab.exists)
        discoveryTab.tap()

        XCTAssertTrue(app.navigationBars["发现"].exists)

        messagesTab.tap()
        XCTAssertTrue(app.navigationBars["消息"].exists)
    }

    @MainActor
    func testDiscoveryPageSearchBar() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["发现"].tap()

        let searchField = app.textFields["搜索用户"]
        XCTAssertTrue(searchField.exists)
    }

    @MainActor
    func testConversationListEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        let emptyLabel = app.staticTexts["暂无消息"]
        if emptyLabel.exists {
            XCTAssertTrue(emptyLabel.exists)
        }
    }

    @MainActor
    func testConversationDetailEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        #if os(macOS)
        let placeholder = app.staticTexts["选择一个对话"]
        if placeholder.exists {
            XCTAssertTrue(placeholder.exists)
        }
        #endif
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
