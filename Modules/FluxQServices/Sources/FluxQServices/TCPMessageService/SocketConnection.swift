//
//  SocketConnection.swift
//  FluxQServices
//
//  Created by martinadamsdev on 2026/2/14.
//

import Foundation

/// TCP 错误类型
public enum TCPError: Error, Equatable, Sendable {
    case socketCreationFailed
    case connectionFailed(host: String, port: Int)
    case connectionTimeout
    case connectionClosed
    case sendFailed
    case partialSend
    case receiveFailed
}

/// BSD Socket TCP 连接封装，提供 async/await API
public final class SocketConnection: Sendable {
    private let socketFD: Int32
    private let _host: String
    private let _port: Int
    private nonisolated(unsafe) var _isConnected: Bool = false

    /// 当前是否已连接
    public var isConnected: Bool { _isConnected }

    /// 创建并连接到指定主机和端口
    public init(host: String, port: Int) async throws {
        self._host = host
        self._port = port

        // 创建 socket
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw TCPError.socketCreationFailed
        }
        self.socketFD = fd

        // 设置非阻塞模式
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        // 构建服务器地址
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        // 发起非阻塞连接
        let connectResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult < 0 && errno != EINPROGRESS {
            Darwin.close(fd)
            throw TCPError.connectionFailed(host: host, port: port)
        }

        // 等待连接完成（使用 select 超时）
        if connectResult < 0 {
            let connected = try await waitForConnection(fd: fd, timeoutSeconds: 5)
            if !connected {
                Darwin.close(fd)
                throw TCPError.connectionFailed(host: host, port: port)
            }
        }

        // 恢复阻塞模式
        _ = fcntl(fd, F_SETFL, flags)

        _isConnected = true
    }

    deinit {
        if _isConnected {
            Darwin.close(socketFD)
        }
    }

    /// 发送数据
    public func send(_ data: Data) async throws {
        guard _isConnected else {
            throw TCPError.connectionClosed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let bytesSent = data.withUnsafeBytes { bufferPtr in
                Darwin.send(self.socketFD, bufferPtr.baseAddress!, data.count, 0)
            }

            if bytesSent < 0 {
                continuation.resume(throwing: TCPError.sendFailed)
            } else if bytesSent < data.count {
                continuation.resume(throwing: TCPError.partialSend)
            } else {
                continuation.resume()
            }
        }
    }

    /// 接收数据
    public func receive(maxLength: Int = 4096) async throws -> Data {
        guard _isConnected else {
            throw TCPError.connectionClosed
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            var buffer = [UInt8](repeating: 0, count: maxLength)
            let bytesRead = Darwin.recv(self.socketFD, &buffer, maxLength, 0)

            if bytesRead > 0 {
                continuation.resume(returning: Data(buffer[0..<bytesRead]))
            } else if bytesRead == 0 {
                continuation.resume(throwing: TCPError.connectionClosed)
            } else {
                continuation.resume(throwing: TCPError.receiveFailed)
            }
        }
    }

    /// 断开连接
    public func disconnect() {
        guard _isConnected else { return }
        _isConnected = false
        Darwin.close(socketFD)
    }

    // MARK: - Private

    /// 使用 select 等待非阻塞连接完成
    private func waitForConnection(fd: Int32, timeoutSeconds: Int) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            var writeSet = fd_set()
            fdZero(&writeSet)
            fdSet(fd, &writeSet)

            var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
            let result = select(fd + 1, nil, &writeSet, nil, &timeout)

            if result > 0 {
                // 检查 socket 是否有错误
                var socketError: Int32 = 0
                var errorLen = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &errorLen)

                if socketError == 0 {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }
}

// MARK: - fd_set helpers

private func fdZero(_ set: inout fd_set) {
    set.fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

private func fdSet(_ fd: Int32, _ set: inout fd_set) {
    let intOffset = Int(fd) / 32
    let bitOffset = Int(fd) % 32
    withUnsafeMutablePointer(to: &set.fds_bits) { ptr in
        let rawPtr = UnsafeMutableRawPointer(ptr)
        let intPtr = rawPtr.assumingMemoryBound(to: Int32.self)
        intPtr[intOffset] |= Int32(1 << bitOffset)
    }
}
