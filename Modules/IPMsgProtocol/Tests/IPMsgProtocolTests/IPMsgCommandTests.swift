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

    // MARK: - Avatar & Extended Commands

    func testAvatarCommandRawValues() {
        XCTAssertEqual(IPMsgCommand.AVATAR.rawValue, 0x00020000)
        XCTAssertEqual(IPMsgCommand.GETAVATAR.rawValue, 0x00030000)
    }

    func testRecallCommandRawValue() {
        XCTAssertEqual(IPMsgCommand.RECALLMSG.rawValue, 0x00010000)
    }

    func testTypingCommandRawValues() {
        XCTAssertEqual(IPMsgCommand.TYPING.rawValue, 0x00040000)
        XCTAssertEqual(IPMsgCommand.STOPTYPING.rawValue, 0x00050000)
    }

    func testRecallListCommandRawValue() {
        XCTAssertEqual(IPMsgCommand.RECALLLIST.rawValue, 0x00060000)
    }

    func testExtendedCommandNames() {
        XCTAssertEqual(IPMsgCommand.AVATAR.name, "AVATAR")
        XCTAssertEqual(IPMsgCommand.GETAVATAR.name, "GETAVATAR")
        XCTAssertEqual(IPMsgCommand.RECALLMSG.name, "RECALLMSG")
        XCTAssertEqual(IPMsgCommand.TYPING.name, "TYPING")
        XCTAssertEqual(IPMsgCommand.STOPTYPING.name, "STOPTYPING")
        XCTAssertEqual(IPMsgCommand.RECALLLIST.name, "RECALLLIST")
    }

    func testExtendedCommandFromRawValue() {
        XCTAssertEqual(IPMsgCommand(rawValue: 0x00020000), .AVATAR)
        XCTAssertEqual(IPMsgCommand(rawValue: 0x00030000), .GETAVATAR)
        XCTAssertEqual(IPMsgCommand(rawValue: 0x00010000), .RECALLMSG)
        XCTAssertEqual(IPMsgCommand(rawValue: 0x00040000), .TYPING)
        XCTAssertEqual(IPMsgCommand(rawValue: 0x00050000), .STOPTYPING)
        XCTAssertEqual(IPMsgCommand(rawValue: 0x00060000), .RECALLLIST)
    }

    func testAvatarCommandPacketEncodeDecode() throws {
        let packet = IPMsgPacket(
            version: 1,
            packetNo: 500,
            sender: "user1",
            hostname: "host1",
            command: .AVATAR,
            payload: "avatar_hash:abc123"
        )

        let encoded = packet.encode()
        XCTAssertEqual(encoded, "1:500:user1:host1:131072:avatar_hash:abc123")

        let decoded = try IPMsgPacket.decode(encoded)
        XCTAssertEqual(decoded.command, .AVATAR)
        XCTAssertEqual(decoded.payload, "avatar_hash:abc123")
    }

    func testGetAvatarCommandPacketEncodeDecode() throws {
        let packet = IPMsgPacket(
            version: 1,
            packetNo: 501,
            sender: "user2",
            hostname: "host2",
            command: .GETAVATAR,
            payload: "request_avatar"
        )

        let encoded = packet.encode()
        let decoded = try IPMsgPacket.decode(encoded)
        XCTAssertEqual(decoded.command, .GETAVATAR)
        XCTAssertEqual(decoded.payload, "request_avatar")
    }
}
