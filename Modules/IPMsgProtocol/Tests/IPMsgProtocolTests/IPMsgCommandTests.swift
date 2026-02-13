//
//  IPMsgCommandTests.swift
//  IPMsgProtocolTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import Testing
@testable import IPMsgProtocol

@Test("基础命令原始值")
func commandRawValues() {
    #expect(IPMsgCommand.BR_ENTRY.rawValue == 0x01)
    #expect(IPMsgCommand.BR_EXIT.rawValue == 0x02)
    #expect(IPMsgCommand.ANSENTRY.rawValue == 0x03)
    #expect(IPMsgCommand.BR_ABSENCE.rawValue == 0x04)
    #expect(IPMsgCommand.SENDMSG.rawValue == 0x20)
    #expect(IPMsgCommand.RECVMSG.rawValue == 0x21)
    #expect(IPMsgCommand.GETFILEDATA.rawValue == 0x60)
    #expect(IPMsgCommand.RELEASEFILES.rawValue == 0x61)
    #expect(IPMsgCommand.GETDIRFILES.rawValue == 0x62)
}

@Test("命令名称")
func commandNames() {
    #expect(IPMsgCommand.BR_ENTRY.name == "BR_ENTRY")
    #expect(IPMsgCommand.SENDMSG.name == "SENDMSG")
    #expect(IPMsgCommand.GETFILEDATA.name == "GETFILEDATA")
}

@Test("从原始值创建命令")
func commandFromRawValue() {
    #expect(IPMsgCommand(rawValue: 0x01) == .BR_ENTRY)
    #expect(IPMsgCommand(rawValue: 0x20) == .SENDMSG)
    #expect(IPMsgCommand(rawValue: 9999) == nil)
}

// MARK: - Avatar & Extended Commands

@Test("头像命令原始值")
func avatarCommandRawValues() {
    #expect(IPMsgCommand.AVATAR.rawValue == 0x00020000)
    #expect(IPMsgCommand.GETAVATAR.rawValue == 0x00030000)
}

@Test("撤回命令原始值")
func recallCommandRawValue() {
    #expect(IPMsgCommand.RECALLMSG.rawValue == 0x00010000)
}

@Test("输入状态命令原始值")
func typingCommandRawValues() {
    #expect(IPMsgCommand.TYPING.rawValue == 0x00040000)
    #expect(IPMsgCommand.STOPTYPING.rawValue == 0x00050000)
}

@Test("撤回列表命令原始值")
func recallListCommandRawValue() {
    #expect(IPMsgCommand.RECALLLIST.rawValue == 0x00060000)
}

@Test("扩展命令名称")
func extendedCommandNames() {
    #expect(IPMsgCommand.AVATAR.name == "AVATAR")
    #expect(IPMsgCommand.GETAVATAR.name == "GETAVATAR")
    #expect(IPMsgCommand.RECALLMSG.name == "RECALLMSG")
    #expect(IPMsgCommand.TYPING.name == "TYPING")
    #expect(IPMsgCommand.STOPTYPING.name == "STOPTYPING")
    #expect(IPMsgCommand.RECALLLIST.name == "RECALLLIST")
}

@Test("扩展命令从原始值创建")
func extendedCommandFromRawValue() {
    #expect(IPMsgCommand(rawValue: 0x00020000) == .AVATAR)
    #expect(IPMsgCommand(rawValue: 0x00030000) == .GETAVATAR)
    #expect(IPMsgCommand(rawValue: 0x00010000) == .RECALLMSG)
    #expect(IPMsgCommand(rawValue: 0x00040000) == .TYPING)
    #expect(IPMsgCommand(rawValue: 0x00050000) == .STOPTYPING)
    #expect(IPMsgCommand(rawValue: 0x00060000) == .RECALLLIST)
}

@Test("头像命令数据包编码解码")
func avatarCommandPacketEncodeDecode() throws {
    let packet = IPMsgPacket(
        version: 1,
        packetNo: 500,
        sender: "user1",
        hostname: "host1",
        command: .AVATAR,
        payload: "avatar_hash:abc123"
    )

    let encoded = packet.encode()
    #expect(encoded == "1:500:user1:host1:131072:avatar_hash:abc123")

    let decoded = try IPMsgPacket.decode(encoded)
    #expect(decoded.command == .AVATAR)
    #expect(decoded.payload == "avatar_hash:abc123")
}

@Test("获取头像命令数据包编码解码")
func getAvatarCommandPacketEncodeDecode() throws {
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
    #expect(decoded.command == .GETAVATAR)
    #expect(decoded.payload == "request_avatar")
}
