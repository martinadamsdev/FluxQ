//
//  IPMsgCommandTests.swift
//  IPMsgProtocolTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import XCTest
@testable import IPMsgProtocol

final class IPMsgCommandTests: XCTestCase {

    func testCommandRawValues() {
        XCTAssertEqual(IPMsgCommand.BR_ENTRY.rawValue, 0x01)
        XCTAssertEqual(IPMsgCommand.BR_EXIT.rawValue, 0x02)
        XCTAssertEqual(IPMsgCommand.ANSENTRY.rawValue, 0x03)
        XCTAssertEqual(IPMsgCommand.BR_ABSENCE.rawValue, 0x04)
        XCTAssertEqual(IPMsgCommand.SENDMSG.rawValue, 0x20)
        XCTAssertEqual(IPMsgCommand.RECVMSG.rawValue, 0x21)
        XCTAssertEqual(IPMsgCommand.GETFILEDATA.rawValue, 0x60)
        XCTAssertEqual(IPMsgCommand.RELEASEFILES.rawValue, 0x61)
        XCTAssertEqual(IPMsgCommand.GETDIRFILES.rawValue, 0x62)
    }

    func testCommandNames() {
        XCTAssertEqual(IPMsgCommand.BR_ENTRY.name, "BR_ENTRY")
        XCTAssertEqual(IPMsgCommand.SENDMSG.name, "SENDMSG")
        XCTAssertEqual(IPMsgCommand.GETFILEDATA.name, "GETFILEDATA")
    }

    func testCommandFromRawValue() {
        XCTAssertEqual(IPMsgCommand(rawValue: 0x01), .BR_ENTRY)
        XCTAssertEqual(IPMsgCommand(rawValue: 0x20), .SENDMSG)
        XCTAssertNil(IPMsgCommand(rawValue: 9999))
    }
}
