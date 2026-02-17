//
//  FileReceiver.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/17.
//

import Foundation

/// 文件接收器 -- 负责接收数据块和进度跟踪
public struct FileReceiver {
    public let expectedSize: Int64
    public private(set) var receivedBytes: Int64
    public private(set) var chunks: [Data]

    public var isComplete: Bool {
        receivedBytes >= expectedSize
    }

    public var progress: Double {
        guard expectedSize > 0 else { return 0 }
        return Double(receivedBytes) / Double(expectedSize)
    }

    public init(expectedSize: Int64, initialOffset: Int64 = 0) {
        self.expectedSize = expectedSize
        self.receivedBytes = initialOffset
        self.chunks = []
    }

    /// 追加接收到的数据块
    public mutating func appendChunk(_ data: Data) {
        chunks.append(data)
        receivedBytes += Int64(data.count)
    }

    /// 组装所有接收到的数据
    public func assembleData() -> Data {
        var result = Data()
        for chunk in chunks {
            result.append(chunk)
        }
        return result
    }
}
