//
//  FileMetadataTests.swift
//  IPMsgProtocolTests
//
//  Created by martinadamsdev on 2026/2/17.
//

import Testing
import Foundation
@testable import IPMsgProtocol

@Suite("FileMetadata Tests")
struct FileMetadataTests {

    @Test("Parse single file attachment from payload")
    func parseSingleFile() throws {
        let payload = "0\u{07}test.txt:a:65d5f000:1:\u{07}"
        let files = FileMetadata.parse(from: payload)

        #expect(files.count == 1)
        #expect(files[0].fileID == 0)
        #expect(files[0].fileName == "test.txt")
        #expect(files[0].fileSize == 10)
        #expect(files[0].fileAttribute == .regular)
    }

    @Test("Parse multiple file attachments")
    func parseMultipleFiles() throws {
        let payload = "0\u{07}file1.txt:64:65d5f000:1:\u{07}1\u{07}file2.pdf:c800:65d5f000:1:\u{07}"
        let files = FileMetadata.parse(from: payload)

        #expect(files.count == 2)
        #expect(files[0].fileName == "file1.txt")
        #expect(files[0].fileSize == 100)
        #expect(files[1].fileName == "file2.pdf")
        #expect(files[1].fileSize == 51200)
    }

    @Test("Parse directory attachment")
    func parseDirectory() throws {
        let payload = "0\u{07}mydir:0:65d5f000:2:\u{07}"
        let files = FileMetadata.parse(from: payload)

        #expect(files.count == 1)
        #expect(files[0].fileName == "mydir")
        #expect(files[0].fileAttribute == .directory)
    }

    @Test("Empty payload returns empty array")
    func emptyPayload() {
        let files = FileMetadata.parse(from: "")
        #expect(files.isEmpty)
    }

    @Test("FileMetadata encode to payload string")
    func encodeToPayload() {
        let metadata = FileMetadata(
            fileID: 0,
            fileName: "test.txt",
            fileSize: 1024,
            modificationTime: Date(timeIntervalSince1970: 0x65d5f000),
            fileAttribute: .regular
        )
        let payload = metadata.encodeToPayload()
        #expect(payload.contains("test.txt"))
        #expect(payload.contains("400"))
    }

    @Test("Encode then parse roundtrip preserves fields")
    func encodeDecodeRoundtrip() {
        let original = FileMetadata(
            fileID: 1,
            fileName: "test.txt",
            fileSize: 1024,
            modificationTime: Date(timeIntervalSince1970: 123456),
            fileAttribute: .regular
        )
        let encoded = original.encodeToPayload()
        let parsed = FileMetadata.parse(from: encoded)
        #expect(parsed.count == 1)
        #expect(parsed[0].fileName == original.fileName)
        #expect(parsed[0].fileSize == original.fileSize)
        #expect(parsed[0].fileAttribute == original.fileAttribute)
    }

    @Test("Parse symlink attribute")
    func parseSymlinkAttribute() {
        // FileAttribute.symlink raw value is 4
        let payload = "0\u{07}link.txt:ff:65d5f000:4:\u{07}"
        let files = FileMetadata.parse(from: payload)

        #expect(files.count == 1)
        #expect(files[0].fileName == "link.txt")
        #expect(files[0].fileAttribute == .symlink)
    }
}
