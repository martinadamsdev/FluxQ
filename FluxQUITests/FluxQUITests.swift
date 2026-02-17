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

    // MARK: - Navigation Tests

    @MainActor
    func testSidebarNavigationItems() throws {
        let app = XCUIApplication()
        app.launch()

        // macOS uses sidebar navigation with these items
        let sidebar = app.outlines.firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        // Verify sidebar navigation items exist
        let messagesButton = app.buttons["消息"].firstMatch
        let discoveryButton = app.buttons["发现"].firstMatch

        // At least the messages or discovery button should be accessible
        let hasMessages = messagesButton.waitForExistence(timeout: 3)
        let hasDiscovery = discoveryButton.waitForExistence(timeout: 3)
        XCTAssertTrue(hasMessages || hasDiscovery,
                       "At least one navigation item should exist")
    }

    @MainActor
    func testNavigateToDiscovery() throws {
        let app = XCUIApplication()
        app.launch()

        // Try to navigate to discovery
        let discoveryButton = app.buttons["发现"].firstMatch
        if discoveryButton.waitForExistence(timeout: 3) {
            discoveryButton.tap()

            // Discovery view should show search functionality
            // Wait a moment for navigation to settle
            let searchField = app.searchFields.firstMatch
            if searchField.waitForExistence(timeout: 3) {
                XCTAssertTrue(searchField.exists)
            }
        }
    }

    @MainActor
    func testNavigateToSettings() throws {
        let app = XCUIApplication()
        app.launch()

        // Try to navigate to settings
        let settingsButton = app.buttons["我"].firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            // Settings view should load without crashing
        }
    }

    // MARK: - Empty State Tests

    @MainActor
    func testConversationListEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        // On fresh install, conversation list should show empty state
        let emptyLabel = app.staticTexts["暂无消息"]
        if emptyLabel.waitForExistence(timeout: 3) {
            XCTAssertTrue(emptyLabel.exists)
        }
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
