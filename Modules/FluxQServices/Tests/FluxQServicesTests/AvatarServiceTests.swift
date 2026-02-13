//
//  AvatarServiceTests.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Foundation
import Testing
@testable import FluxQServices

@MainActor
struct AvatarServiceTests {

    @Test("Set my avatar stores data and computes hash")
    func setMyAvatar() {
        let service = AvatarService()
        let testData = Data("test-avatar-image".utf8)

        service.setMyAvatar(testData)

        #expect(service.myAvatarData == testData)
        #expect(service.myAvatarHash != nil)
        #expect(service.myAvatarHash?.isEmpty == false)
    }

    @Test("Avatar hash is deterministic for same data")
    func avatarHashDeterministic() {
        let service = AvatarService()
        let testData = Data("identical-content".utf8)

        service.setMyAvatar(testData)
        let hash1 = service.myAvatarHash

        service.setMyAvatar(testData)
        let hash2 = service.myAvatarHash

        #expect(hash1 == hash2)
    }

    @Test("Different data produces different hash")
    func differentDataDifferentHash() {
        let service = AvatarService()

        service.setMyAvatar(Data("avatar-1".utf8))
        let hash1 = service.myAvatarHash

        service.setMyAvatar(Data("avatar-2".utf8))
        let hash2 = service.myAvatarHash

        #expect(hash1 != hash2)
    }

    @Test("Cache avatar by hash")
    func cacheAvatarByHash() {
        let service = AvatarService()
        let testData = Data("cached-avatar".utf8)
        let hash = "test-hash-123"

        service.cacheAvatar(data: testData, forHash: hash)

        #expect(service.cachedAvatar(forHash: hash) == testData)
    }

    @Test("Cache returns nil for unknown hash")
    func cacheReturnsNilForUnknown() {
        let service = AvatarService()

        #expect(service.cachedAvatar(forHash: "nonexistent") == nil)
    }

    @Test("Set my avatar also caches it")
    func setMyAvatarCachesIt() {
        let service = AvatarService()
        let testData = Data("my-avatar-data".utf8)

        service.setMyAvatar(testData)

        let hash = service.myAvatarHash!
        #expect(service.cachedAvatar(forHash: hash) == testData)
    }

    @Test("Clear my avatar removes data and hash")
    func clearMyAvatar() {
        let service = AvatarService()
        let testData = Data("to-be-cleared".utf8)

        service.setMyAvatar(testData)
        #expect(service.myAvatarData != nil)
        #expect(service.myAvatarHash != nil)

        service.clearMyAvatar()

        #expect(service.myAvatarData == nil)
        #expect(service.myAvatarHash == nil)
    }

    @Test("Compress avatar reduces large data")
    func compressAvatarReducesLargeData() {
        let service = AvatarService()
        // Create data larger than maxAvatarSize
        let largeData = Data(repeating: 0xFF, count: 300 * 1024)

        let compressed = service.compressAvatar(largeData, maxSize: 256 * 1024)

        #expect(compressed.count <= 256 * 1024)
    }

    @Test("Compress avatar preserves small data")
    func compressAvatarPreservesSmallData() {
        let service = AvatarService()
        let smallData = Data("small".utf8)

        let result = service.compressAvatar(smallData, maxSize: 256 * 1024)

        #expect(result == smallData)
    }

    @Test("Cache has size limit")
    func cacheSizeLimit() {
        let service = AvatarService(maxCacheEntries: 3)

        service.cacheAvatar(data: Data("a".utf8), forHash: "hash-1")
        service.cacheAvatar(data: Data("b".utf8), forHash: "hash-2")
        service.cacheAvatar(data: Data("c".utf8), forHash: "hash-3")
        service.cacheAvatar(data: Data("d".utf8), forHash: "hash-4")

        // The oldest entry should have been evicted
        #expect(service.cacheCount == 3)
    }
}
