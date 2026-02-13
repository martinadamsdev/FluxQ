//
//  AvatarService.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/14.
//

import Foundation
import CryptoKit

/// 头像管理服务
///
/// 负责头像的设置、SHA-256 哈希计算、压缩和内存缓存。
@MainActor
public final class AvatarService: ObservableObject {
    // MARK: - Published State

    /// 当前用户头像数据
    @Published public private(set) var myAvatarData: Data?

    /// 当前用户头像的 SHA-256 哈希
    @Published public private(set) var myAvatarHash: String?

    // MARK: - Cache

    private var cache: [String: Data] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheEntries: Int

    /// 缓存中的条目数量
    public var cacheCount: Int { cache.count }

    // MARK: - Initialization

    public init(maxCacheEntries: Int = 50) {
        self.maxCacheEntries = maxCacheEntries
    }

    // MARK: - My Avatar

    /// 设置当前用户的头像
    public func setMyAvatar(_ data: Data) {
        myAvatarData = data
        myAvatarHash = sha256Hash(of: data)
        cacheAvatar(data: data, forHash: myAvatarHash!)
    }

    /// 清除当前用户的头像
    public func clearMyAvatar() {
        myAvatarData = nil
        myAvatarHash = nil
    }

    // MARK: - Cache Operations

    /// 缓存头像数据
    public func cacheAvatar(data: Data, forHash hash: String) {
        if cache[hash] == nil {
            // New entry: enforce size limit
            if cacheOrder.count >= maxCacheEntries {
                let evicted = cacheOrder.removeFirst()
                cache.removeValue(forKey: evicted)
            }
            cacheOrder.append(hash)
        }
        cache[hash] = data
    }

    /// 获取缓存的头像数据
    public func cachedAvatar(forHash hash: String) -> Data? {
        cache[hash]
    }

    // MARK: - Compression

    /// 压缩头像数据到指定最大尺寸
    public func compressAvatar(_ data: Data, maxSize: Int) -> Data {
        if data.count <= maxSize {
            return data
        }
        // Use progressive truncation as a simple compression strategy.
        // In production, this would use platform-specific image compression APIs.
        return data.prefix(maxSize)
    }

    // MARK: - Private

    private func sha256Hash(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
