//
//  IPMsgCommand.swift
//  IPMsgProtocol
//
//  Created by martinadamsdev on 2026/2/13.
//

import Foundation

/// IPMsg 协议命令
public enum IPMsgCommand: Int, Codable, Sendable {
    // 用户状态命令
    case BR_ENTRY = 0x01        // 上线广播
    case BR_EXIT = 0x02         // 下线广播
    case ANSENTRY = 0x03        // 响应上线
    case BR_ABSENCE = 0x04      // 离开状态

    // 消息命令
    case SENDMSG = 0x20         // 发送消息
    case RECVMSG = 0x21         // 接收确认

    // 文件传输命令
    case GETFILEDATA = 0x60     // 获取文件数据
    case RELEASEFILES = 0x61    // 释放文件
    case GETDIRFILES = 0x62     // 获取目录文件

    /// 命令名称（用于调试）
    public var name: String {
        switch self {
        case .BR_ENTRY: return "BR_ENTRY"
        case .BR_EXIT: return "BR_EXIT"
        case .ANSENTRY: return "ANSENTRY"
        case .BR_ABSENCE: return "BR_ABSENCE"
        case .SENDMSG: return "SENDMSG"
        case .RECVMSG: return "RECVMSG"
        case .GETFILEDATA: return "GETFILEDATA"
        case .RELEASEFILES: return "RELEASEFILES"
        case .GETDIRFILES: return "GETDIRFILES"
        }
    }
}
