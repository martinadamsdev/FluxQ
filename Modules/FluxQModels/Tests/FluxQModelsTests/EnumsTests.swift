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

    @Test("MessageStatus has all 6 cases")
    func messageStatusCases() {
        let allStatuses: [MessageStatus] = [.pending, .sending, .sent, .delivered, .read, .failed]
        #expect(allStatuses.count == 6)
    }

    @Test("MessageStatus raw values are correct strings")
    func messageStatusRawValues() {
        #expect(MessageStatus.pending.rawValue == "pending")
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

    // MARK: - TransferStatus

    @Test("TransferStatus has all 5 cases")
    func transferStatusAllCases() {
        let allCases: [TransferStatus] = [.pending, .transferring, .completed, .failed, .cancelled]
        #expect(allCases.count == 5)
        #expect(allCases.contains(.pending))
        #expect(allCases.contains(.transferring))
        #expect(allCases.contains(.completed))
        #expect(allCases.contains(.failed))
        #expect(allCases.contains(.cancelled))
    }

    @Test("TransferStatus raw values are correct strings")
    func transferStatusRawValues() {
        #expect(TransferStatus.pending.rawValue == "pending")
        #expect(TransferStatus.transferring.rawValue == "transferring")
        #expect(TransferStatus.completed.rawValue == "completed")
        #expect(TransferStatus.failed.rawValue == "failed")
        #expect(TransferStatus.cancelled.rawValue == "cancelled")
    }

    @Test("TransferStatus Codable round-trip")
    func transferStatusCodable() throws {
        let allCases: [TransferStatus] = [.pending, .transferring, .completed, .failed, .cancelled]
        for status in allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TransferStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    @Test("TransferStatus can be initialized from raw value")
    func transferStatusFromRawValue() {
        #expect(TransferStatus(rawValue: "pending") == .pending)
        #expect(TransferStatus(rawValue: "transferring") == .transferring)
        #expect(TransferStatus(rawValue: "completed") == .completed)
        #expect(TransferStatus(rawValue: "failed") == .failed)
        #expect(TransferStatus(rawValue: "cancelled") == .cancelled)
        #expect(TransferStatus(rawValue: "invalid") == nil)
    }

    // MARK: - TransferDirection

    @Test("TransferDirection has all 2 cases")
    func transferDirectionAllCases() {
        let allCases: [TransferDirection] = [.outgoing, .incoming]
        #expect(allCases.count == 2)
    }

    @Test("TransferDirection raw values are correct strings")
    func transferDirectionRawValues() {
        #expect(TransferDirection.outgoing.rawValue == "outgoing")
        #expect(TransferDirection.incoming.rawValue == "incoming")
    }

    @Test("TransferDirection Codable round-trip")
    func transferDirectionCodable() throws {
        let allCases: [TransferDirection] = [.outgoing, .incoming]
        for direction in allCases {
            let data = try JSONEncoder().encode(direction)
            let decoded = try JSONDecoder().decode(TransferDirection.self, from: data)
            #expect(decoded == direction)
        }
    }

    @Test("TransferDirection can be initialized from raw value")
    func transferDirectionFromRawValue() {
        #expect(TransferDirection(rawValue: "outgoing") == .outgoing)
        #expect(TransferDirection(rawValue: "incoming") == .incoming)
        #expect(TransferDirection(rawValue: "invalid") == nil)
    }

    // MARK: - MessageType

    @Test("MessageType has all 3 cases")
    func messageTypeAllCases() {
        let allCases: [MessageType] = [.text, .file, .image]
        #expect(allCases.count == 3)
        #expect(allCases.contains(.text))
        #expect(allCases.contains(.file))
        #expect(allCases.contains(.image))
    }

    @Test("MessageType raw values are correct strings")
    func messageTypeRawValues() {
        #expect(MessageType.text.rawValue == "text")
        #expect(MessageType.file.rawValue == "file")
        #expect(MessageType.image.rawValue == "image")
    }

    @Test("MessageType Codable round-trip")
    func messageTypeCodable() throws {
        let allCases: [MessageType] = [.text, .file, .image]
        for msgType in allCases {
            let data = try JSONEncoder().encode(msgType)
            let decoded = try JSONDecoder().decode(MessageType.self, from: data)
            #expect(decoded == msgType)
        }
    }

    @Test("MessageType can be initialized from raw value")
    func messageTypeFromRawValue() {
        #expect(MessageType(rawValue: "text") == .text)
        #expect(MessageType(rawValue: "file") == .file)
        #expect(MessageType(rawValue: "image") == .image)
        #expect(MessageType(rawValue: "invalid") == nil)
    }
}
