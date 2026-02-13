import Testing
import Foundation
@testable import FluxQModels

@Suite("Enums Tests")
struct EnumsTests {

    // MARK: - UserStatus

    @Test("UserStatus has all 4 cases")
    func userStatusCases() {
        let allCases = UserStatus.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.online))
        #expect(allCases.contains(.away))
        #expect(allCases.contains(.busy))
        #expect(allCases.contains(.offline))
    }

    @Test("UserStatus displayName returns correct Chinese names")
    func userStatusDisplayName() {
        #expect(UserStatus.online.displayName == "在线")
        #expect(UserStatus.away.displayName == "离开")
        #expect(UserStatus.busy.displayName == "忙碌")
        #expect(UserStatus.offline.displayName == "离线")
    }

    @Test("UserStatus raw values are correct strings")
    func userStatusRawValues() {
        #expect(UserStatus.online.rawValue == "online")
        #expect(UserStatus.away.rawValue == "away")
        #expect(UserStatus.busy.rawValue == "busy")
        #expect(UserStatus.offline.rawValue == "offline")
    }

    @Test("UserStatus Codable round-trip")
    func userStatusCodable() throws {
        for status in UserStatus.allCases {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(UserStatus.self, from: encoded)
            #expect(decoded == status)
        }
    }

    @Test("UserStatus CaseIterable returns 4 values")
    func userStatusCaseIterable() {
        #expect(UserStatus.allCases.count == 4)
        let uniqueCases = Set(UserStatus.allCases.map(\.rawValue))
        #expect(uniqueCases.count == 4)
    }

    @Test("UserStatus can be initialized from raw value")
    func userStatusFromRawValue() {
        #expect(UserStatus(rawValue: "online") == .online)
        #expect(UserStatus(rawValue: "away") == .away)
        #expect(UserStatus(rawValue: "busy") == .busy)
        #expect(UserStatus(rawValue: "offline") == .offline)
        #expect(UserStatus(rawValue: "invalid") == nil)
    }

    // MARK: - MessageStatus

    @Test("MessageStatus has all 5 cases")
    func messageStatusCases() {
        let allStatuses: [MessageStatus] = [.sending, .sent, .delivered, .read, .failed]
        #expect(allStatuses.count == 5)
    }

    @Test("MessageStatus raw values are correct strings")
    func messageStatusRawValues() {
        #expect(MessageStatus.sending.rawValue == "sending")
        #expect(MessageStatus.sent.rawValue == "sent")
        #expect(MessageStatus.delivered.rawValue == "delivered")
        #expect(MessageStatus.read.rawValue == "read")
        #expect(MessageStatus.failed.rawValue == "failed")
    }

    @Test("MessageStatus Codable round-trip")
    func messageStatusCodable() throws {
        let allStatuses: [MessageStatus] = [.sending, .sent, .delivered, .read, .failed]
        for status in allStatuses {
            let encoded = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(MessageStatus.self, from: encoded)
            #expect(decoded == status)
        }
    }

    @Test("MessageStatus can be initialized from raw value")
    func messageStatusFromRawValue() {
        #expect(MessageStatus(rawValue: "sending") == .sending)
        #expect(MessageStatus(rawValue: "sent") == .sent)
        #expect(MessageStatus(rawValue: "delivered") == .delivered)
        #expect(MessageStatus(rawValue: "read") == .read)
        #expect(MessageStatus(rawValue: "failed") == .failed)
        #expect(MessageStatus(rawValue: "unknown") == nil)
    }

    // MARK: - ConversationType

    @Test("ConversationType has all 2 cases")
    func conversationTypeCases() {
        let allTypes: [ConversationType] = [.private, .group]
        #expect(allTypes.count == 2)
    }

    @Test("ConversationType raw values are correct strings")
    func conversationTypeRawValues() {
        #expect(ConversationType.private.rawValue == "private")
        #expect(ConversationType.group.rawValue == "group")
    }

    @Test("ConversationType Codable round-trip")
    func conversationTypeCodable() throws {
        let allTypes: [ConversationType] = [.private, .group]
        for type in allTypes {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(ConversationType.self, from: encoded)
            #expect(decoded == type)
        }
    }

    @Test("ConversationType can be initialized from raw value")
    func conversationTypeFromRawValue() {
        #expect(ConversationType(rawValue: "private") == .private)
        #expect(ConversationType(rawValue: "group") == .group)
        #expect(ConversationType(rawValue: "channel") == nil)
    }
}
