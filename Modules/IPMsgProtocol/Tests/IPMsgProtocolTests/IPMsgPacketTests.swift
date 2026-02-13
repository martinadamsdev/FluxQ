//
//  IPMsgPacketTests.swift
//  IPMsgProtocolTests
//
//  Created by martinadamsdev on 2026/2/13.
//

import XCTest
@testable import IPMsgProtocol

final class IPMsgPacketTests: XCTestCase {

    func testEncodeDecodeRoundtrip() throws {
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
        XCTAssertEqual(decoded, original)
    }

    func testEncodeFormat() {
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
        XCTAssertEqual(encoded, "1:100:user1:host1:32:test message")
    }

    func testDecodeValidMessage() throws {
        // Given
        let message = "1:200:alice:MacBook:1:online"

        // When
        let packet = try IPMsgPacket.decode(message)

        // Then
        XCTAssertEqual(packet.version, 1)
        XCTAssertEqual(packet.packetNo, 200)
        XCTAssertEqual(packet.sender, "alice")
        XCTAssertEqual(packet.hostname, "MacBook")
        XCTAssertEqual(packet.command, .BR_ENTRY)
        XCTAssertEqual(packet.payload, "online")
    }

    func testDecodeInvalidFormat() {
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
            XCTAssertThrowsError(try IPMsgPacket.decode(message)) { error in
                XCTAssertTrue(error is IPMsgError)
            }
        }
    }

    func testDecodeInvalidCommand() {
        // Given
        let message = "1:100:user:host:9999:payload"

        // When & Then
        XCTAssertThrowsError(try IPMsgPacket.decode(message)) { error in
            guard case IPMsgError.invalidCommand(let code) = error else {
                XCTFail("Expected invalidCommand error")
                return
            }
            XCTAssertEqual(code, 9999)
        }
    }

    func testPayloadWithColons() throws {
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
        XCTAssertEqual(decoded.payload, "message:with:colons")
    }

    func testEmptyPayload() throws {
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
        XCTAssertEqual(decoded.payload, "")
    }
}
