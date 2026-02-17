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
}
