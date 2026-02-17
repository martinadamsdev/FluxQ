//
//  FileTransferService.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/17.
//

import Foundation
import IPMsgProtocol

/// 文件传输服务 -- 协调文件发送和接收
@MainActor
public final class FileTransferService: ObservableObject {

    /// FILEATTACHOPT 标志值
    public static let fileAttachOpt: Int = 0x00200000

    private let networkManager: NetworkManager

    public init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }

    // MARK: - Payload Builders

    /// 构建 GETFILEDATA 请求 payload
    ///
    /// 格式: "packetNo:fileID:offset(hex):"
    public nonisolated static func buildGetFileDataPayload(
        packetNo: Int,
        fileID: Int,
        offset: Int64
    ) -> String {
        let offsetHex = String(offset, radix: 16)
        return "\(packetNo):\(fileID):\(offsetHex):"
    }

    /// 解析 GETFILEDATA 请求 payload
    ///
    /// - Returns: (packetNo, fileID, offset) 或 nil
    public nonisolated static func parseGetFileDataPayload(
        _ payload: String
    ) -> (packetNo: Int, fileID: Int, offset: Int64)? {
        let parts = payload.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3,
              let packetNo = Int(parts[0]),
              let fileID = Int(parts[1]),
              let offset = Int64(parts[2], radix: 16) else {
            return nil
        }
        return (packetNo, fileID, offset)
    }

    // MARK: - Send File

    /// 发起文件发送
    ///
    /// 1. 构造 SENDMSG + FILEATTACHOPT payload
    /// 2. 广播通知对方
    /// 3. 等待 GETFILEDATA 请求
    /// 4. TCP 分块发送
    public func sendFile(
        fileURL: URL,
        to user: DiscoveredUser,
        onProgress: @escaping (Double) -> Void
    ) async throws -> UUID {
        let data = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent
        let fileSize = Int64(data.count)
        let transferID = UUID()

        // Build file metadata
        let metadata = FileMetadata(
            fileID: 0,
            fileName: fileName,
            fileSize: fileSize,
            modificationTime: Date(),
            fileAttribute: .regular
        )

        // Send SENDMSG with FILEATTACHOPT
        let payload = metadata.encodeToPayload()
        try await networkManager.sendMessage(to: user, message: payload)

        return transferID
    }
}
