//
//  FileTransferServiceTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/17.
//

import Testing
import Foundation
@testable import FluxQServices
@testable import IPMsgProtocol

@Suite("FileTransferService Tests")
struct FileTransferServiceTests {

    @Test("FileSender chunks data into 64KB blocks")
    func chunksData() {
        let data = Data(repeating: 0xAB, count: 150_000)  // ~146KB
        let chunks = FileSender.chunk(data: data, blockSize: 65536)
        #expect(chunks.count == 3)
        #expect(chunks[0].count == 65536)
        #expect(chunks[1].count == 65536)
        #expect(chunks[2].count == 150_000 - 65536 * 2)
    }

    @Test("FileSender chunks empty data")
    func chunksEmptyData() {
        let data = Data()
        let chunks = FileSender.chunk(data: data, blockSize: 65536)
        #expect(chunks.isEmpty)
    }

    @Test("FileSender chunks data exactly 64KB")
    func chunksExactBlock() {
        let data = Data(repeating: 0xCD, count: 65536)
        let chunks = FileSender.chunk(data: data, blockSize: 65536)
        #expect(chunks.count == 1)
        #expect(chunks[0].count == 65536)
    }

    @Test("FileSender respects offset for resume")
    func chunksWithOffset() {
        let data = Data(repeating: 0xEF, count: 100_000)
        let chunks = FileSender.chunk(data: data, blockSize: 65536, offset: 65536)
        // Should only return chunks from offset onwards
        #expect(chunks.count == 1)
        #expect(chunks[0].count == 100_000 - 65536)
    }

    @Test("FileReceiver assembles chunks into complete data")
    func assembleChunks() {
        var receiver = FileReceiver(expectedSize: 100)
        let chunk1 = Data(repeating: 0x01, count: 50)
        let chunk2 = Data(repeating: 0x02, count: 50)

        receiver.appendChunk(chunk1)
        #expect(receiver.receivedBytes == 50)
        #expect(!receiver.isComplete)

        receiver.appendChunk(chunk2)
        #expect(receiver.receivedBytes == 100)
        #expect(receiver.isComplete)
    }

    @Test("FileReceiver handles resume from offset")
    func resumeFromOffset() {
        var receiver = FileReceiver(expectedSize: 100, initialOffset: 40)
        #expect(receiver.receivedBytes == 40)

        let chunk = Data(repeating: 0x03, count: 60)
        receiver.appendChunk(chunk)
        #expect(receiver.receivedBytes == 100)
        #expect(receiver.isComplete)
    }

    @Test("FileMetadata GETFILEDATA payload format")
    func getFileDataPayload() {
        let payload = FileTransferService.buildGetFileDataPayload(
            packetNo: 100, fileID: 0, offset: 65536
        )
        #expect(payload == "100:0:10000:")  // offset in hex
    }

    @Test("Parse GETFILEDATA request payload")
    func parseGetFileDataRequest() {
        let result = FileTransferService.parseGetFileDataPayload("100:0:10000:")!
        #expect(result.packetNo == 100)
        #expect(result.fileID == 0)
        #expect(result.offset == 65536)
    }

    @Test("parseGetFileDataPayload returns nil for invalid input")
    func parseGetFileDataInvalid() {
        #expect(FileTransferService.parseGetFileDataPayload("") == nil)
        #expect(FileTransferService.parseGetFileDataPayload("abc:def:ghi:") == nil)
        #expect(FileTransferService.parseGetFileDataPayload("100") == nil)
    }

    @Test("buildGetFileDataPayload with zero offset")
    func buildPayloadZeroOffset() {
        let payload = FileTransferService.buildGetFileDataPayload(
            packetNo: 1, fileID: 0, offset: 0
        )
        #expect(payload == "1:0:0:")
    }

    @Test("fileAttachOpt constant value")
    func fileAttachOptValue() {
        #expect(FileTransferService.fileAttachOpt == 0x00200000)
    }

    // MARK: - sendFile Tests

    @MainActor
    @Test("sendFile sends message with file metadata to user")
    func sendFileSuccess() async throws {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let service = FileTransferService(networkManager: networkManager)

        // Create a temp file
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("test-send.txt")
        let content = "Hello file transfer!"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20", port: 2425
        )

        var progressValues: [Double] = []
        let transferID = try await service.sendFile(
            fileURL: fileURL, to: user,
            onProgress: { progressValues.append($0) }
        )

        // Should return a valid UUID
        #expect(transferID != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))

        // Should have sent a message via network
        #expect(transport.sentMessages.count == 1)
        #expect(transport.sentMessages[0].host == "192.168.1.20")
        #expect(transport.sentMessages[0].port == 2425)

        // Payload should contain the file name
        let sentPayload = String(data: transport.sentMessages[0].data, encoding: .utf8)!
        let decoded = try IPMsgPacket.decode(sentPayload)
        #expect(decoded.command == .SENDMSG)
        // The payload should contain the file metadata (filename)
        #expect(decoded.payload.contains("test-send.txt"))
    }

    @MainActor
    @Test("sendFile throws when file does not exist")
    func sendFileNotFound() async throws {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let service = FileTransferService(networkManager: networkManager)

        let badURL = URL(fileURLWithPath: "/tmp/nonexistent-file-\(UUID().uuidString).txt")
        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20"
        )

        await #expect(throws: Error.self) {
            try await service.sendFile(
                fileURL: badURL, to: user,
                onProgress: { _ in }
            )
        }

        // No message should be sent
        #expect(transport.sentMessages.isEmpty)
    }

    @MainActor
    @Test("sendFile throws when network fails")
    func sendFileNetworkFailure() async throws {
        let transport = MockNetworkTransport()
        transport.shouldFailOnSend = true
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let service = FileTransferService(networkManager: networkManager)

        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("test-net-fail.txt")
        try "data".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20"
        )

        await #expect(throws: Error.self) {
            try await service.sendFile(
                fileURL: fileURL, to: user,
                onProgress: { _ in }
            )
        }
    }

    @MainActor
    @Test("sendFile uses correct port from DiscoveredUser")
    func sendFileUsesUserPort() async throws {
        let transport = MockNetworkTransport()
        let networkManager = NetworkManager(port: 2425, transport: transport)
        let service = FileTransferService(networkManager: networkManager)

        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("test-port.txt")
        try "port test".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let user = DiscoveredUser(
            senderName: "bob", nickname: "Bob", hostname: "bob-mac",
            ipAddress: "192.168.1.20", port: 5000
        )

        _ = try await service.sendFile(
            fileURL: fileURL, to: user,
            onProgress: { _ in }
        )

        #expect(transport.sentMessages[0].port == 5000)
    }
}
