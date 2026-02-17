//
//  FileSender.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/17.
//

import Foundation

/// 文件发送器 -- 负责分块和数据准备
public enum FileSender {

    /// 默认块大小：64KB
    public static let defaultBlockSize = 65536

    /// 将数据分成固定大小的块
    ///
    /// - Parameters:
    ///   - data: 原始文件数据
    ///   - blockSize: 块大小（默认 64KB）
    ///   - offset: 起始偏移量（用于断点续传）
    /// - Returns: 数据块数组
    public static func chunk(
        data: Data,
        blockSize: Int = defaultBlockSize,
        offset: Int64 = 0
    ) -> [Data] {
        let startIndex = Int(offset)
        guard startIndex < data.count else { return [] }

        let remainingData = data[startIndex...]
        var chunks: [Data] = []
        var currentIndex = remainingData.startIndex

        while currentIndex < remainingData.endIndex {
            let endIndex = min(currentIndex + blockSize, remainingData.endIndex)
            chunks.append(Data(remainingData[currentIndex..<endIndex]))
            currentIndex = endIndex
        }

        return chunks
    }
}
