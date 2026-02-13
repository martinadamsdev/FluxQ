//
//  MockTCPServer.swift
//  FluxQServicesTests
//
//  Created by martinadamsdev on 2026/2/14.
//

import Foundation

/// Mock TCP 服务器，用于 SocketConnection 单元测试
actor MockTCPServer {
    private let port: Int
    private var serverSocket: Int32 = -1
    private var clientSocket: Int32 = -1
    private(set) var receivedData: Data = Data()
    private(set) var isRunning = false

    init(port: Int) {
        self.port = port
    }

    /// 启动服务器并开始监听
    func start() throws {
        serverSocket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw MockTCPServerError.socketCreationFailed
        }

        // 允许端口重用
        var optval: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &optval, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            Darwin.close(serverSocket)
            throw MockTCPServerError.bindFailed(port: port)
        }

        guard Darwin.listen(serverSocket, 1) == 0 else {
            Darwin.close(serverSocket)
            throw MockTCPServerError.listenFailed
        }

        isRunning = true
    }

    /// 接受一个客户端连接
    func acceptConnection() throws {
        var clientAddr = sockaddr_in()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let socket = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.accept(serverSocket, sockaddrPtr, &clientAddrLen)
            }
        }

        guard socket >= 0 else {
            throw MockTCPServerError.acceptFailed
        }

        clientSocket = socket
    }

    /// 从已连接的客户端读取数据
    func readData(maxLength: Int = 4096) throws -> Data {
        guard clientSocket >= 0 else {
            throw MockTCPServerError.noClientConnected
        }

        var buffer = [UInt8](repeating: 0, count: maxLength)
        let bytesRead = Darwin.recv(clientSocket, &buffer, maxLength, 0)

        guard bytesRead > 0 else {
            throw MockTCPServerError.readFailed
        }

        let data = Data(buffer[0..<bytesRead])
        receivedData.append(data)
        return data
    }

    /// 向已连接的客户端发送数据
    func sendData(_ data: Data) throws {
        guard clientSocket >= 0 else {
            throw MockTCPServerError.noClientConnected
        }

        let bytesSent = data.withUnsafeBytes { bufferPtr in
            Darwin.send(clientSocket, bufferPtr.baseAddress!, data.count, 0)
        }

        guard bytesSent == data.count else {
            throw MockTCPServerError.sendFailed
        }
    }

    /// 停止服务器
    func stop() {
        if clientSocket >= 0 {
            Darwin.close(clientSocket)
            clientSocket = -1
        }
        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }
        isRunning = false
    }
}

enum MockTCPServerError: Error {
    case socketCreationFailed
    case bindFailed(port: Int)
    case listenFailed
    case acceptFailed
    case noClientConnected
    case readFailed
    case sendFailed
}
