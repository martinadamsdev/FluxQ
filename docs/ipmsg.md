# IPMsg 协议深度分析

**基于**: [shirouzu/ipmsg](https://github.com/shirouzu/ipmsg) v4.99r3
**分析日期**: 2026-02-13

## 协议概述

IP Messenger (IPMsg) 是一个基于 TCP/UDP 的局域网即时通讯协议,由 H.Shirouzu 于 1996 年创建。该协议无需服务器,采用 P2P 方式通信,简单、轻量、免费。

### 协议特点

- **无服务器架构**: 纯 P2P,无需中心服务器
- **UDP 广播发现**: 通过 UDP 广播自动发现局域网用户
- **TCP 可靠传输**: 消息和文件通过 TCP 传输
- **跨平台**: Windows、Mac、Linux、Java 等多平台实现
- **BSD 许可证**: 开源,商用友好

## 协议版本

| 版本 | 值 | 说明 |
|------|-----|------|
| IPMSG_VERSION | 0x0001 | 基础版本(v1) |
| IPMSG_NEW_VERSION | 0x0003 | 当前版本(v3) |

**端口**: 2425 (0x0979)

## 数据包格式

### 基础格式

```
版本号:包编号:发送者名称:发送者主机名:命令字:附加数据
```

**字段分隔符**: `:` (冒号)

**示例**:
```
1:100:Alice:DESKTOP-ABC:32:
1:101:Bob:MacBook-Pro:33:Hello Alice!
```

### 字段详解

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| 版本号 | UInt32 | 协议版本,通常为 1 | `1` |
| 包编号 | UInt32 | 递增的包序号,用于去重和确认 | `100` |
| 发送者名称 | String | 用户昵称 | `Alice` |
| 发送者主机名 | String | 设备主机名 | `DESKTOP-ABC` |
| 命令字 | UInt32 | 低8位=命令,高24位=选项 | `32` (0x20) |
| 附加数据 | String | 消息内容或扩展信息 | `Hello!` |

### 命令字结构

```c
命令字 (32位) = 命令类型 (低8位) | 选项标志 (高24位)
```

**提取宏**:
```c
#define GET_MODE(command)   (command & 0x000000ffUL)  // 获取命令类型
#define GET_OPT(command)    (command & 0xffffff00UL)  // 获取选项标志
```

**示例**:
```
命令字 = 0x00000120
  命令类型 = 0x20 (SENDMSG)
  选项标志 = 0x100 (SENDCHECKOPT - 需要确认)
```

## 命令字定义

### 广播命令 (UDP)

| 命令 | 值 | 说明 |
|------|-----|------|
| BR_ENTRY | 0x00000001 | 上线广播 |
| BR_EXIT | 0x00000002 | 下线广播 |
| ANSENTRY | 0x00000003 | 上线应答 |
| BR_ABSENCE | 0x00000004 | 状态变更(离开/忙碌等) |

### 列表管理 (UDP)

| 命令 | 值 | 说明 |
|------|-----|------|
| BR_ISGETLIST | 0x00000010 | 查询是否可获取用户列表 |
| OKGETLIST | 0x00000011 | 同意提供用户列表 |
| GETLIST | 0x00000012 | 请求用户列表 |
| ANSLIST | 0x00000013 | 返回用户列表 |

### 消息传输 (TCP)

| 命令 | 值 | 说明 |
|------|-----|------|
| SENDMSG | 0x00000020 | 发送消息 |
| RECVMSG | 0x00000021 | 消息确认 |
| READMSG | 0x00000030 | 已读确认 |
| DELMSG | 0x00000031 | 删除消息 |
| ANSREADMSG | 0x00000032 | 已读应答 |

### 文件传输 (TCP)

| 命令 | 值 | 说明 |
|------|-----|------|
| GETFILEDATA | 0x00000060 | 请求文件数据 |
| RELEASEFILES | 0x00000061 | 通知文件信息 |
| GETDIRFILES | 0x00000062 | 请求目录文件 |

### 加密相关 (TCP)

| 命令 | 值 | 说明 |
|------|-----|------|
| GETPUBKEY | 0x00000072 | 请求公钥 |
| ANSPUBKEY | 0x00000073 | 返回公钥 |

### 代理和目录服务

| 命令 | 值 | 说明 |
|------|-----|------|
| AGENT_REQ | 0x000000a0 | 代理请求 |
| AGENT_ANSREQ | 0x000000a1 | 代理应答 |
| DIR_POLL | 0x000000b0 | 目录服务轮询 |
| DIR_BROADCAST | 0x000000b2 | 目录服务广播 |

## 选项标志

### 全局选项 (所有命令适用)

| 标志 | 值 | 说明 |
|------|-----|------|
| ABSENCEOPT | 0x00000100 | 离线状态 |
| SERVEROPT | 0x00000200 | 服务器模式 |
| DIALUPOPT | 0x00010000 | 拨号连接 |
| FILEATTACHOPT | 0x00200000 | 文件附件 |
| ENCRYPTOPT | 0x00400000 | 支持加密 |
| UTF8OPT | 0x00800000 | UTF-8 编码 |
| CAPUTF8OPT | 0x01000000 | 支持 UTF-8 |
| CLIPBOARDOPT | 0x08000000 | 剪贴板支持 |
| DIR_MASTER | 0x10000000 | 目录服务主节点 |

### 消息专用选项

| 标志 | 值 | 说明 |
|------|-----|------|
| SENDCHECKOPT | 0x00000100 | 需要发送确认 |
| SECRETOPT | 0x00000200 | 秘密消息 |
| BROADCASTOPT | 0x00000400 | 广播消息 |
| MULTICASTOPT | 0x00000800 | 组播消息 |
| PASSWORDOPT | 0x00008000 | 密码保护 |
| READCHECKOPT | 0x00100000 | 需要已读确认 |

## 加密支持

### RSA 密钥长度

| 标志 | 值 | 说明 |
|------|-----|------|
| RSA_1024 | 0x00000002 | 1024 位 RSA |
| RSA_2048 | 0x00000004 | 2048 位 RSA |
| RSA_4096 | 0x00000008 | 4096 位 RSA |

### 对称加密算法

| 标志 | 值 | 说明 |
|------|-----|------|
| BLOWFISH_128 | 0x00020000 | Blowfish 128 位 |
| AES_256 | 0x00100000 | AES 256 位 |

### 签名算法

| 标志 | 值 | 说明 |
|------|-----|------|
| SIGN_SHA1 | 0x20000000 | SHA-1 签名 |
| SIGN_SHA256 | 0x40000000 | SHA-256 签名 |

### 其他加密选项

| 标志 | 值 | 说明 |
|------|-----|------|
| ENCODE_BASE64 | 0x01000000 | Base64 编码 |
| PACKETNO_IV | 0x00800000 | 使用包编号作为 IV |

## 文件传输

### 文件类型

| 类型 | 值 | 说明 |
|------|-----|------|
| FILE_REGULAR | 0x00000001 | 普通文件 |
| FILE_DIR | 0x00000002 | 目录 |
| FILE_SYMLINK | 0x00000004 | 符号链接 |
| FILE_CDEV | 0x00000005 | 字符设备 (UNIX) |
| FILE_BDEV | 0x00000006 | 块设备 (UNIX) |
| FILE_FIFO | 0x00000007 | 命名管道 (UNIX) |
| FILE_CLIPBOARD | 0x00000020 | 剪贴板内容 |

### 文件属性

| 属性 | 值 | 说明 |
|------|-----|------|
| FILE_RONLYOPT | 0x00000100 | 只读 |
| FILE_HIDDENOPT | 0x00001000 | 隐藏 |
| FILE_ARCHIVEOPT | 0x00004000 | 归档 |
| FILE_SYSTEMOPT | 0x00008000 | 系统文件 |

### 扩展属性

| 属性 | 值 | 说明 |
|------|-----|------|
| FILE_UID | 0x00000001 | UNIX 用户 ID |
| FILE_GID | 0x00000003 | UNIX 组 ID |
| FILE_PERM | 0x00000010 | UNIX 权限 |
| FILE_CTIME | 0x00000013 | 创建时间 |
| FILE_MTIME | 0x00000014 | 修改时间 |
| FILE_ATIME | 0x00000015 | 访问时间 |

## 协议流程

### 1. 用户发现流程

```
启动应用
    ↓
发送 BR_ENTRY (UDP 广播到 255.255.255.255:2425)
    命令字: IPMSG_BR_ENTRY | IPMSG_ABSENCEOPT (if away)
    附加数据: 部门/组名称
    ↓
监听 UDP 2425 端口
    ↓
收到其他用户的 BR_ENTRY
    ↓
回复 ANS_ENTRY (UDP 单播到发送方 IP)
    命令字: IPMSG_ANSENTRY | 状态标志
    附加数据: 部门/组名称
    ↓
添加用户到在线列表
    ↓
定时心跳 (每60秒发送 BR_ABSENCE)
    ↓
退出时发送 BR_EXIT (UDP 广播)
```

### 2. 消息发送流程

```
发送方:
    建立 TCP 连接到 接收方IP:2425
    ↓
    发送 SENDMSG 包
    命令字: IPMSG_SENDMSG | IPMSG_SENDCHECKOPT
    附加数据: 消息内容
    ↓
    等待 RECVMSG 确认 (超时处理: 3秒)
    ↓
    收到确认
    ↓
    关闭连接

接收方:
    监听 TCP 2425 端口
    ↓
    收到 SENDMSG 包
    ↓
    解析并显示消息
    ↓
    如果设置了 SENDCHECKOPT,回复 RECVMSG
    命令字: IPMSG_RECVMSG
    包编号: 与收到的包相同
    ↓
    关闭连接
```

### 3. 文件传输流程

```
发送方:
    1. 发送 SENDMSG with FILEATTACHOPT
       附加数据格式: "文件ID\a文件名:文件大小:修改时间:文件属性:\a"

    2. 监听 TCP 端口,等待接收方请求

    3. 收到 GETFILEDATA 请求
       附加数据: "包编号:文件ID:偏移量:"

    4. 发送文件数据块 (分块大小: 通常 64KB)

    5. 发送完成后关闭连接

接收方:
    1. 收到 SENDMSG with FILEATTACHOPT

    2. 解析文件信息,显示接收对话框

    3. 用户确认接收后,建立 TCP 连接到发送方

    4. 发送 GETFILEDATA 请求
       附加数据: "包编号:文件ID:偏移量:"
       (偏移量用于断点续传)

    5. 接收文件数据块,显示进度

    6. 接收完成,保存文件

    7. 关闭连接
```

### 4. 加密消息流程

```
首次通信:
    A → B: GETPUBKEY (请求 B 的公钥)
    B → A: ANSPUBKEY (返回公钥 + 加密能力标志)

    A 使用 B 的公钥加密:
    - 生成随机对称密钥(AES-256/Blowfish-128)
    - 用 B 的 RSA 公钥加密对称密钥
    - 用对称密钥加密消息内容

    A → B: SENDMSG | ENCRYPTOPT
    附加数据格式:
        加密能力标志:加密后的密钥(Base64):加密后的消息(Base64)

    B 解密:
    - 用自己的 RSA 私钥解密对称密钥
    - 用对称密钥解密消息内容
```

## 网络实现细节

### UDP 广播

```c
// 创建 UDP socket
int sockfd = socket(AF_INET, SOCK_DGRAM, 0);

// 启用广播
int broadcast = 1;
setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));

// 设置目标地址为广播地址
struct sockaddr_in addr;
addr.sin_family = AF_INET;
addr.sin_port = htons(2425);
addr.sin_addr.s_addr = inet_addr("255.255.255.255");  // 或子网广播地址

// 发送数据
sendto(sockfd, packet, packet_len, 0, (struct sockaddr*)&addr, sizeof(addr));
```

### TCP 连接

```c
// 发送方: 建立连接
int sockfd = socket(AF_INET, SOCK_STREAM, 0);
struct sockaddr_in addr;
addr.sin_family = AF_INET;
addr.sin_port = htons(2425);
addr.sin_addr.s_addr = inet_addr("192.168.1.100");  // 接收方 IP

connect(sockfd, (struct sockaddr*)&addr, sizeof(addr));
send(sockfd, packet, packet_len, 0);

// 接收方: 监听连接
int listenfd = socket(AF_INET, SOCK_STREAM, 0);
bind(listenfd, ...);
listen(listenfd, 5);

int connfd = accept(listenfd, ...);
recv(connfd, buffer, buffer_size, 0);
```

## 兼容性注意事项

### 编码

- **推荐**: UTF-8 (使用 UTF8OPT 标志)
- **兼容**: 需要支持 GBK/Shift-JIS 等本地编码(尤其是与 Windows FeiQ 互操作)
- **检测**: 尝试 UTF-8 解码,失败则尝试系统默认编码

### 协议版本

- **v1**: 基础协议,所有客户端必须支持
- **v3**: 扩展协议,向后兼容 v1
- **策略**: 优先使用 v3 特性,遇到 v1 客户端自动降级

### 文件路径

- **Windows**: 反斜杠 `\`, 盘符 `C:\`
- **Unix/Mac**: 正斜杠 `/`
- **处理**: 统一转换为目标平台格式

### 换行符

- **Windows**: `\r\n`
- **Unix/Mac**: `\n`
- **处理**: 统一使用 `\n`,显示时转换

## IPMsg vs FeiQ

### FeiQ 扩展

FeiQ (飞秋) 是 IPMsg 的中国本地化版本,增加了一些扩展:

- **群组广播**: 支持部门/组的概念
- **截图功能**: Windows 截图工具集成
- **表情包**: 内置表情支持
- **消息加密**: 扩展的加密选项

### 互操作性

FluxQ 需要兼容:
- ✅ 基础 IPMsg 协议(BR_ENTRY, SENDMSG 等)
- ✅ 文件传输
- ✅ UTF-8 和 GBK 编码
- ⚠️ FeiQ 特定扩展(群组、表情)仅在 FluxQ 客户端间支持
- ⚠️ 加密仅在支持加密的客户端间使用

## Swift 实现建议

### 数据包编解码

```swift
struct IPMsgPacket {
    let version: UInt32
    let packetNo: UInt32
    let sender: String
    let hostname: String
    let command: UInt32
    let payload: String

    func encode() -> Data {
        let packet = "\(version):\(packetNo):\(sender):\(hostname):\(command):\(payload)"
        return packet.data(using: .utf8)!
    }

    static func decode(_ data: Data) throws -> IPMsgPacket {
        // 尝试 UTF-8
        guard let string = String(data: data, encoding: .utf8) else {
            // 尝试 GBK (兼容 FeiQ)
            if let gbkString = String(data: data, encoding: .gb_18030_2000) {
                return try parsePacket(gbkString)
            }
            throw IPMsgError.invalidEncoding
        }
        return try parsePacket(string)
    }
}
```

### 网络层

```swift
// UDP 广播使用 BSD Socket (精确控制)
// TCP 连接使用 Network.framework (现代 async API)

import Network

// TCP 发送
let connection = NWConnection(
    host: NWEndpoint.Host(targetIP),
    port: NWEndpoint.Port(2425),
    using: .tcp
)

connection.start(queue: .main)
try await connection.send(content: packet.encode())

// UDP 广播使用 BSD Socket
let sockfd = socket(AF_INET, SOCK_DGRAM, 0)
var broadcast: Int32 = 1
setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
// ... 发送数据
```

## 参考资料

- **原始实现**: [shirouzu/ipmsg](https://github.com/shirouzu/ipmsg)
- **官方网站**: [ipmsg.org](http://ipmsg.org/)
- **协议文档**: 见原始仓库的 `protocol.txt`
- **许可证**: BSD License

## 总结

IPMsg 协议设计简洁高效:
- ✅ 文本格式数据包,易于调试
- ✅ UDP 广播自动发现,无需配置
- ✅ TCP 可靠传输,支持大文件
- ✅ 可选加密,保护隐私
- ✅ 跨平台,生态丰富

FluxQ 将完整实现该协议,确保与 FeiQ 和其他 IPMsg 客户端的完美互操作。
