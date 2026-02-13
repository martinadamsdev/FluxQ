//
//  IPMsgPacketTests.swift
//  IPMsgProtocolTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import Testing
@testable import IPMsgProtocol

@Test("编码解码往返一致性")
func encodeDecodeRoundtrip() throws {
    // Given
    let original = IPMsgPacket(
        version: 1,
        packetNo: 12345,
        sender: "testuser",
        hostname: "MacBook-Pro",
        command: .BR_ENTRY,
        payload: "Hello FluxQ"
    )

    // When
    let encoded = original.encode()
    let decoded = try IPMsgPacket.decode(encoded)

    // Then
    #expect(decoded == original)
}

@Test("编码格式正确性")
func encodeFormat() {
    // Given
    let packet = IPMsgPacket(
        version: 1,
        packetNo: 100,
        sender: "user1",
        hostname: "host1",
        command: .SENDMSG,
        payload: "test message"
    )

    // When
    let encoded = packet.encode()

    // Then
    #expect(encoded == "1:100:user1:host1:32:test message")
}

@Test("解码有效消息")
func decodeValidMessage() throws {
    // Given
    let message = "1:200:alice:MacBook:1:online"

    // When
    let packet = try IPMsgPacket.decode(message)

    // Then
    #expect(packet.version == 1)
    #expect(packet.packetNo == 200)
    #expect(packet.sender == "alice")
    #expect(packet.hostname == "MacBook")
    #expect(packet.command == .BR_ENTRY)
    #expect(packet.payload == "online")
}

@Test("解码无效格式抛出错误")
func decodeInvalidFormat() {
    // Given
    let invalidMessages = [
        "invalid",
        "1:2:3:4",  // 缺少部分
        "a:b:c:d:e:f",  // 版本不是数字
        "1:b:c:d:e:f",  // packetNo 不是数字
        "1:2:alice:host:invalid:payload"  // command 不是数字
    ]

    // When & Then
    for message in invalidMessages {
        #expect(throws: IPMsgError.self) {
            try IPMsgPacket.decode(message)
        }
    }
}

@Test("解码无效命令抛出 invalidCommand 错误")
func decodeInvalidCommand() throws {
    // Given
    let message = "1:100:user:host:9999:payload"

    // When & Then
    let error = try #require(throws: IPMsgError.self) {
        try IPMsgPacket.decode(message)
    }
    guard case .invalidCommand(let code) = error else {
        Issue.record("Expected invalidCommand error")
        return
    }
    #expect(code == 9999)
}

@Test("Payload 包含冒号的处理")
func payloadWithColons() throws {
    // Given
    let packet = IPMsgPacket(
        version: 1,
        packetNo: 300,
        sender: "user",
        hostname: "host",
        command: .SENDMSG,
        payload: "message:with:colons"
    )

    // When
    let encoded = packet.encode()
    let decoded = try IPMsgPacket.decode(encoded)

    // Then
    #expect(decoded.payload == "message:with:colons")
}

@Test("空 Payload 的处理")
func emptyPayload() throws {
    // Given
    let packet = IPMsgPacket(
        version: 1,
        packetNo: 400,
        sender: "user",
        hostname: "host",
        command: .BR_EXIT,
        payload: ""
    )

    // When
    let encoded = packet.encode()
    let decoded = try IPMsgPacket.decode(encoded)

    // Then
    #expect(decoded.payload == "")
}
