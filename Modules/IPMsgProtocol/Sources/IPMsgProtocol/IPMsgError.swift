//
//  IPMsgError.swift
//  IPMsgProtocol
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation

/// IPMsg 协议错误
public enum IPMsgError: Error, LocalizedError {
    case invalidFormat(String)
    case networkError(String)
    case timeout
    case invalidCommand(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let details):
            return "Invalid message format: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .timeout:
            return "Operation timed out"
        case .invalidCommand(let code):
            return "Invalid command code: \(code)"
        }
    }
}
