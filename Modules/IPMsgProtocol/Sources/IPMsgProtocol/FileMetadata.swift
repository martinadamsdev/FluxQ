//
//  FileMetadata.swift
//  IPMsgProtocol
//
//  Created by martinadamsdev on 2026/2/17.
//

import Foundation

/// IPMsg 文件属性类型
public enum FileAttribute: UInt32, Sendable, Equatable {
    case regular = 0x00000001
    case directory = 0x00000002
    case symlink = 0x00000004
    case clipboard = 0x00000020
}

/// IPMsg 文件传输元数据
public struct FileMetadata: Sendable, Equatable {
    public let fileID: Int
    public let fileName: String
    public let fileSize: Int64
    public let modificationTime: Date
    public let fileAttribute: FileAttribute

    public init(
        fileID: Int,
        fileName: String,
        fileSize: Int64,
        modificationTime: Date,
        fileAttribute: FileAttribute
    ) {
        self.fileID = fileID
        self.fileName = fileName
        self.fileSize = fileSize
        self.modificationTime = modificationTime
        self.fileAttribute = fileAttribute
    }

    /// 从 payload 字符串解析文件元数据列表
    public static func parse(from payload: String) -> [FileMetadata] {
        guard !payload.isEmpty else { return [] }

        var results: [FileMetadata] = []
        let segments = payload.split(separator: "\u{07}", omittingEmptySubsequences: true)

        var i = 0
        while i < segments.count {
            let fileIDStr = String(segments[i])

            if let fileID = Int(fileIDStr), i + 1 < segments.count {
                let infoStr = String(segments[i + 1])
                if let metadata = parseFileInfo(fileID: fileID, info: infoStr) {
                    results.append(metadata)
                }
                i += 2
            } else {
                i += 1
            }
        }

        return results
    }

    /// 编码为 payload 字符串
    public func encodeToPayload() -> String {
        let sizeHex = String(fileSize, radix: 16)
        let mtimeHex = String(Int(modificationTime.timeIntervalSince1970), radix: 16)
        let attrHex = String(fileAttribute.rawValue, radix: 16)
        return "\(fileID)\u{07}\(fileName):\(sizeHex):\(mtimeHex):\(attrHex):\u{07}"
    }

    private static func parseFileInfo(fileID: Int, info: String) -> FileMetadata? {
        let parts = info.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4 else { return nil }

        let fileName = parts[0]
        let fileSize = Int64(parts[1], radix: 16) ?? 0
        let modTime = Int(parts[2], radix: 16).map {
            Date(timeIntervalSince1970: TimeInterval($0))
        } ?? Date()
        let attrRaw = UInt32(parts[3], radix: 16) ?? 1
        let attr = FileAttribute(rawValue: attrRaw) ?? .regular

        return FileMetadata(
            fileID: fileID,
            fileName: fileName,
            fileSize: fileSize,
            modificationTime: modTime,
            fileAttribute: attr
        )
    }
}
