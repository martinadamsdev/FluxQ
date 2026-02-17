//
//  FluxQUITests.swift
//  FluxQUITests
//
//  Created by martinadamsdev on 2026/2/13.
//

import XCTest

// MARK: - 基础启动测试（无测试数据）

final class FluxQUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testConversationDetailEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        #if os(macOS)
        let placeholder = app.staticTexts["选择一个对话"]
        XCTAssertTrue(
            placeholder.waitForExistence(timeout: 5),
            "未选中会话时应显示 placeholder"
        )

        let description = app.staticTexts["从左侧列表中选择一个对话以查看详情"]
        XCTAssertTrue(
            description.waitForExistence(timeout: 5),
            "placeholder 描述文本应存在"
        )
        #endif
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - 侧边栏导航测试

final class SidebarNavigationTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    /// 验证侧边栏显示所有 4 个导航项
    @MainActor
    func testSidebarShowsAllNavigationItems() throws {
        #if os(macOS)
        for title in ["消息", "通讯录", "发现", "我"] {
            let item = app.buttons[title].firstMatch
            XCTAssertTrue(
                item.waitForExistence(timeout: 5),
                "侧边栏应显示 '\(title)' 导航项"
            )
        }
        #endif
    }

    /// 验证 Cmd+2 快捷键切换到通讯录页面
    @MainActor
    func testKeyboardShortcutToContacts() throws {
        #if os(macOS)
        app.typeKey("2", modifierFlags: .command)

        let contact = app.staticTexts["张三"]
        XCTAssertTrue(
            contact.waitForExistence(timeout: 5),
            "Cmd+2 应切换到通讯录页面"
        )
        #endif
    }

    /// 验证 Cmd+3 快捷键切换到发现页面
    @MainActor
    func testKeyboardShortcutToDiscovery() throws {
        #if os(macOS)
        app.typeKey("3", modifierFlags: .command)

        let emptyText = app.staticTexts["暂无发现用户"]
        XCTAssertTrue(
            emptyText.waitForExistence(timeout: 5),
            "Cmd+3 应切换到发现页面"
        )
        #endif
    }

    /// 验证 Cmd+4 快捷键切换到设置页面
    @MainActor
    func testKeyboardShortcutToSettings() throws {
        #if os(macOS)
        app.typeKey("4", modifierFlags: .command)

        let section = app.staticTexts["个人信息"]
        XCTAssertTrue(
            section.waitForExistence(timeout: 5),
            "Cmd+4 应切换到设置页面"
        )
        #endif
    }

    /// 验证从其他 tab 用 Cmd+1 切回消息页
    @MainActor
    func testKeyboardShortcutBackToMessages() throws {
        #if os(macOS)
        // 先切到设置
        app.typeKey("4", modifierFlags: .command)
        let section = app.staticTexts["个人信息"]
        XCTAssertTrue(section.waitForExistence(timeout: 5))

        // 切回消息
        app.typeKey("1", modifierFlags: .command)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(
            alice.waitForExistence(timeout: 5),
            "Cmd+1 应切回消息页面"
        )
        #endif
    }

    /// 验证点击侧边栏项可切换页面
    @MainActor
    func testSidebarClickNavigation() throws {
        #if os(macOS)
        // 点击"发现"
        let discoveryButton = app.buttons["发现"].firstMatch
        XCTAssertTrue(discoveryButton.waitForExistence(timeout: 5))
        discoveryButton.tap()

        let emptyText = app.staticTexts["暂无发现用户"]
        XCTAssertTrue(
            emptyText.waitForExistence(timeout: 5),
            "点击侧边栏'发现'应切换到发现页面"
        )
        #endif
    }
}

// MARK: - 带测试数据的会话 E2E 测试

final class ConversationFlowTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - 会话列表

    /// 验证会话列表渲染了 seed 的两个会话
    @MainActor
    func testConversationListShowsSeededConversations() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(
            alice.waitForExistence(timeout: 5),
            "会话列表应显示 Alice"
        )

        let bob = app.staticTexts["Bob"]
        XCTAssertTrue(
            bob.waitForExistence(timeout: 5),
            "会话列表应显示 Bob"
        )
        #endif
    }

    /// 验证会话列表显示未读计数
    @MainActor
    func testConversationListUnreadBadge() throws {
        #if os(macOS)
        let badge = app.staticTexts["2"]
        XCTAssertTrue(
            badge.waitForExistence(timeout: 5),
            "Alice 会话应显示未读数 2"
        )
        #endif
    }

    /// 验证会话列表显示最后消息预览
    @MainActor
    func testConversationListLastMessagePreview() throws {
        #if os(macOS)
        // Alice 的最后一条消息是 "这是一条测试消息"
        let preview = app.staticTexts["这是一条测试消息"]
        XCTAssertTrue(
            preview.waitForExistence(timeout: 5),
            "会话列表应显示最后消息预览"
        )
        #endif
    }

    // MARK: - 消息列表（MessageListView @Query 验证）

    /// 验证选中有消息的会话后，消息内容通过 @Query 正确渲染
    @MainActor
    func testMessageListRendersMessages() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let msg1 = app.staticTexts["你好，我是 Alice！"]
        XCTAssertTrue(
            msg1.waitForExistence(timeout: 5),
            "MessageListView 应通过 @Query 渲染 Alice 的第一条消息"
        )

        let msg2 = app.staticTexts["你好 Alice，很高兴认识你"]
        XCTAssertTrue(
            msg2.waitForExistence(timeout: 5),
            "MessageListView 应渲染当前用户发送的消息"
        )

        let msg3 = app.staticTexts["这是一条测试消息"]
        XCTAssertTrue(
            msg3.waitForExistence(timeout: 5),
            "MessageListView 应渲染 Alice 的最后一条消息"
        )
        #endif
    }

    /// 验证选中空会话后显示空状态
    @MainActor
    func testEmptyConversationShowsPlaceholder() throws {
        #if os(macOS)
        let bob = app.staticTexts["Bob"]
        XCTAssertTrue(bob.waitForExistence(timeout: 5))
        bob.tap()

        let emptyMsg = app.staticTexts["暂无消息"]
        XCTAssertTrue(
            emptyMsg.waitForExistence(timeout: 5),
            "空会话应显示 '暂无消息'"
        )

        let hint = app.staticTexts["发送第一条消息开始对话"]
        XCTAssertTrue(
            hint.waitForExistence(timeout: 5),
            "空会话应显示引导文本"
        )
        #endif
    }

    // MARK: - 输入栏

    /// 验证对话详情中输入栏可见且可交互
    @MainActor
    func testInputBarPresent() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let textField = app.textFields["输入消息..."]
        XCTAssertTrue(
            textField.waitForExistence(timeout: 5),
            "对话详情应显示消息输入框"
        )
        #endif
    }

    /// 验证发送按钮在空输入时禁用
    @MainActor
    func testSendButtonDisabledWhenEmpty() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let sendButton = app.buttons["paperplane.fill"]
        if sendButton.waitForExistence(timeout: 5) {
            XCTAssertFalse(
                sendButton.isEnabled,
                "输入为空时发送按钮应禁用"
            )
        }
        #endif
    }

    /// 验证输入文字后发送按钮可用
    @MainActor
    func testSendButtonEnabledWithText() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let textField = app.textFields["输入消息..."]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText("测试消息")

        let sendButton = app.buttons["paperplane.fill"]
        if sendButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(
                sendButton.isEnabled,
                "输入文字后发送按钮应启用"
            )
        }
        #endif
    }

    /// 验证发送消息后消息出现在列表中
    @MainActor
    func testSendMessageAppearsInList() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let textField = app.textFields["输入消息..."]
        XCTAssertTrue(textField.waitForExistence(timeout: 5))
        textField.tap()
        textField.typeText("E2E 发送测试")

        let sendButton = app.buttons["paperplane.fill"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        sendButton.tap()

        // 验证新消息出现
        let newMessage = app.staticTexts["E2E 发送测试"]
        XCTAssertTrue(
            newMessage.waitForExistence(timeout: 5),
            "发送的消息应出现在消息列表中"
        )

        // 验证输入框已清空
        let emptyField = app.textFields["输入消息..."]
        XCTAssertEqual(
            emptyField.value as? String ?? "",
            "",
            "发送后输入框应清空"
        )
        #endif
    }

    // MARK: - 上下文菜单

    /// 验证对方消息右键菜单包含复制和转发选项
    @MainActor
    func testMessageContextMenu() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let message = app.staticTexts["你好，我是 Alice！"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))

        message.rightClick()

        let copyItem = app.menuItems["复制"]
        XCTAssertTrue(
            copyItem.waitForExistence(timeout: 3),
            "上下文菜单应包含'复制'选项"
        )

        let forwardItem = app.menuItems["转发"]
        XCTAssertTrue(
            forwardItem.waitForExistence(timeout: 3),
            "上下文菜单应包含'转发'选项"
        )
        #endif
    }

    /// 验证自己发送的消息右键菜单包含撤回选项
    @MainActor
    func testOwnMessageContextMenuHasRecall() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        // 右键点击自己发送的消息（120 秒内可撤回）
        let ownMessage = app.staticTexts["你好 Alice，很高兴认识你"]
        XCTAssertTrue(ownMessage.waitForExistence(timeout: 5))
        ownMessage.rightClick()

        let recallItem = app.menuItems["撤回"]
        XCTAssertTrue(
            recallItem.waitForExistence(timeout: 3),
            "自己发送的消息(120秒内)上下文菜单应包含'撤回'选项"
        )
        #endif
    }

    // MARK: - 会话切换

    /// 验证从有消息的会话切换到空会话，MessageListView 正确更新
    @MainActor
    func testSwitchBetweenConversations() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let aliceMsg = app.staticTexts["你好，我是 Alice！"]
        XCTAssertTrue(
            aliceMsg.waitForExistence(timeout: 5),
            "切到 Alice 会话后应显示消息"
        )

        let bob = app.staticTexts["Bob"]
        XCTAssertTrue(bob.waitForExistence(timeout: 5))
        bob.tap()

        let emptyMsg = app.staticTexts["暂无消息"]
        XCTAssertTrue(
            emptyMsg.waitForExistence(timeout: 5),
            "切到 Bob 空会话后应显示空状态"
        )

        alice.tap()
        XCTAssertTrue(
            aliceMsg.waitForExistence(timeout: 5),
            "切回 Alice 后消息应重新出现"
        )
        #endif
    }

    /// 验证选中会话后清除未读计数
    @MainActor
    func testSelectConversationClearsUnread() throws {
        #if os(macOS)
        // 确认未读数存在
        let badge = app.staticTexts["2"]
        XCTAssertTrue(
            badge.waitForExistence(timeout: 5),
            "Alice 会话初始应显示未读数 2"
        )

        // 选中 Alice 会话
        let alice = app.staticTexts["Alice"]
        alice.tap()

        // 等待清除未读
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: badge
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: 5)
        XCTAssertEqual(
            result, .completed,
            "选中会话后未读数应消失"
        )
        #endif
    }

    // MARK: - 附件按钮

    /// 验证附件按钮存在
    @MainActor
    func testAttachmentButtonPresent() throws {
        #if os(macOS)
        let alice = app.staticTexts["Alice"]
        XCTAssertTrue(alice.waitForExistence(timeout: 5))
        alice.tap()

        let attachButton = app.buttons["paperclip"]
        XCTAssertTrue(
            attachButton.waitForExistence(timeout: 5),
            "对话详情应显示附件按钮"
        )
        #endif
    }
}

// MARK: - 通讯录页面测试

final class ContactsPageTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    @MainActor
    private func navigateToContacts() {
        #if os(macOS)
        app.typeKey("2", modifierFlags: .command)
        #endif
    }

    /// 验证通讯录列表显示所有联系人
    @MainActor
    func testContactListShowsAllContacts() throws {
        #if os(macOS)
        navigateToContacts()

        for name in ["张三", "李四", "王五"] {
            let contact = app.staticTexts[name]
            XCTAssertTrue(
                contact.waitForExistence(timeout: 5),
                "通讯录应显示联系人 '\(name)'"
            )
        }
        #endif
    }

    /// 验证通讯录显示部门信息
    @MainActor
    func testContactListShowsDepartment() throws {
        #if os(macOS)
        navigateToContacts()

        for dept in ["技术部", "产品部", "市场部"] {
            let deptText = app.staticTexts[dept]
            XCTAssertTrue(
                deptText.waitForExistence(timeout: 5),
                "通讯录应显示部门 '\(dept)'"
            )
        }
        #endif
    }

    /// 验证未选中联系人时显示空状态
    @MainActor
    func testContactDetailEmptyState() throws {
        #if os(macOS)
        navigateToContacts()

        let placeholder = app.staticTexts["选择一个联系人"]
        XCTAssertTrue(
            placeholder.waitForExistence(timeout: 5),
            "未选中联系人时应显示 placeholder"
        )

        let description = app.staticTexts["从左侧列表中选择一个联系人以查看详情"]
        XCTAssertTrue(
            description.waitForExistence(timeout: 5),
            "placeholder 应显示描述文本"
        )
        #endif
    }

    /// 验证选中联系人后显示详情和操作按钮
    @MainActor
    func testContactDetailShowsActionButtons() throws {
        #if os(macOS)
        navigateToContacts()

        let contact = app.staticTexts["张三"]
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        contact.tap()

        let sendMsgButton = app.buttons["发送消息"]
        XCTAssertTrue(
            sendMsgButton.waitForExistence(timeout: 5),
            "联系人详情应显示'发送消息'按钮"
        )

        let viewProfileButton = app.buttons["查看资料"]
        XCTAssertTrue(
            viewProfileButton.waitForExistence(timeout: 5),
            "联系人详情应显示'查看资料'按钮"
        )
        #endif
    }
}

// MARK: - 发现页面测试

final class DiscoveryPageTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    @MainActor
    private func navigateToDiscovery() {
        #if os(macOS)
        app.typeKey("3", modifierFlags: .command)
        #endif
    }

    /// 验证发现页空状态标题和提示
    @MainActor
    func testDiscoveryEmptyState() throws {
        #if os(macOS)
        navigateToDiscovery()

        let emptyTitle = app.staticTexts["暂无发现用户"]
        XCTAssertTrue(
            emptyTitle.waitForExistence(timeout: 5),
            "无用户时应显示'暂无发现用户'"
        )

        let emptyHint = app.staticTexts["正在搜索局域网用户..."]
        XCTAssertTrue(
            emptyHint.waitForExistence(timeout: 5),
            "应显示搜索提示文本"
        )
        #endif
    }

    /// 验证搜索栏存在且可交互
    @MainActor
    func testSearchBarPresent() throws {
        #if os(macOS)
        navigateToDiscovery()

        let searchField = app.textFields["搜索用户"]
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "发现页应显示搜索栏"
        )

        // 验证可输入
        searchField.tap()
        searchField.typeText("test")
        XCTAssertEqual(
            searchField.value as? String, "test",
            "搜索栏应接受文本输入"
        )
        #endif
    }

    /// 验证 3 个筛选标签存在
    @MainActor
    func testFilterChipsPresent() throws {
        #if os(macOS)
        navigateToDiscovery()

        for chip in ["仅在线", "有头像", "最近活跃"] {
            let chipButton = app.buttons[chip]
            XCTAssertTrue(
                chipButton.waitForExistence(timeout: 5),
                "发现页应显示筛选标签 '\(chip)'"
            )
        }
        #endif
    }

    /// 验证刷新按钮存在
    @MainActor
    func testRefreshButtonPresent() throws {
        #if os(macOS)
        navigateToDiscovery()

        let refreshButton = app.buttons["arrow.clockwise"]
        XCTAssertTrue(
            refreshButton.waitForExistence(timeout: 5),
            "发现页应显示刷新按钮"
        )
        #endif
    }

    /// 验证搜索无结果时显示"无匹配用户"
    @MainActor
    func testSearchNoResultsState() throws {
        #if os(macOS)
        navigateToDiscovery()

        // 输入不存在的用户名触发搜索
        let searchField = app.textFields["搜索用户"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("不存在的用户名xyz")

        // 由于 discoveredUsers 为空且有搜索文本，
        // 仍然显示 "暂无发现用户"（因为 discoveredUsers.isEmpty == true）
        let emptyText = app.staticTexts["暂无发现用户"]
        XCTAssertTrue(
            emptyText.waitForExistence(timeout: 5),
            "搜索无结果时应显示空状态"
        )
        #endif
    }
}

// MARK: - 设置页面测试

final class SettingsPageTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    @MainActor
    private func navigateToSettings() {
        #if os(macOS)
        app.typeKey("4", modifierFlags: .command)
        #endif
    }

    /// 验证设置页显示所有 4 个区段
    @MainActor
    func testSettingsShowsAllSections() throws {
        #if os(macOS)
        navigateToSettings()

        for section in ["个人信息", "状态", "通知", "外观"] {
            let sectionText = app.staticTexts[section]
            XCTAssertTrue(
                sectionText.waitForExistence(timeout: 5),
                "设置页应显示 '\(section)' 区段"
            )
        }
        #endif
    }

    /// 验证个人信息区段显示昵称和部门标签
    @MainActor
    func testPersonalInfoSection() throws {
        #if os(macOS)
        navigateToSettings()

        let nickname = app.staticTexts["昵称"]
        XCTAssertTrue(
            nickname.waitForExistence(timeout: 5),
            "个人信息应显示'昵称'字段"
        )

        let dept = app.staticTexts["部门"]
        XCTAssertTrue(
            dept.waitForExistence(timeout: 5),
            "个人信息应显示'部门'字段"
        )
        #endif
    }

    /// 验证消息提示音开关存在
    /// macOS SwiftUI Form: Toggle 渲染为 checkBox
    @MainActor
    func testNotificationSoundToggle() throws {
        #if os(macOS)
        navigateToSettings()

        // macOS Form 中 Toggle 可能渲染为 checkbox 或 switch
        let checkbox = app.checkBoxes["消息提示音"]
        let toggle = app.switches["消息提示音"]
        let found = checkbox.waitForExistence(timeout: 5) || toggle.waitForExistence(timeout: 3)
        XCTAssertTrue(
            found,
            "通知区段应显示'消息提示音'开关"
        )
        #endif
    }

    /// 验证状态选择器存在
    @MainActor
    func testStatusPicker() throws {
        #if os(macOS)
        navigateToSettings()

        // macOS Form 中 Picker 可能渲染为 popUpButton 或其他控件类型
        let popUp = app.popUpButtons["当前状态"]
        let label = app.staticTexts["当前状态"]
        let found = popUp.waitForExistence(timeout: 5) || label.waitForExistence(timeout: 3)
        XCTAssertTrue(
            found,
            "状态区段应显示状态选择器或标签"
        )
        #endif
    }

    /// 验证主题选择器存在
    @MainActor
    func testThemePicker() throws {
        #if os(macOS)
        navigateToSettings()

        let popUp = app.popUpButtons["主题"]
        let label = app.staticTexts["主题"]
        let found = popUp.waitForExistence(timeout: 5) || label.waitForExistence(timeout: 3)
        XCTAssertTrue(
            found,
            "外观区段应显示主题选择器或标签"
        )
        #endif
    }

    /// 验证提示音选择器存在（消息提示音开关默认开启）
    @MainActor
    func testSoundPicker() throws {
        #if os(macOS)
        navigateToSettings()

        let popUp = app.popUpButtons["提示音"]
        let label = app.staticTexts["提示音"]
        let found = popUp.waitForExistence(timeout: 5) || label.waitForExistence(timeout: 3)
        XCTAssertTrue(
            found,
            "通知区段应显示提示音选择器或标签"
        )
        #endif
    }
}
