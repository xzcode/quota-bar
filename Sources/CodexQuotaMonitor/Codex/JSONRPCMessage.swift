import Foundation

/// A small JSON value type lets the client tolerate additive app-server fields.
enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw JSONRPCError.invalidMessage
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var doubleValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }
}

/// JSON-RPC request with an optional object parameter payload.
struct JSONRPCRequest: Encodable, Sendable {
    let jsonrpc = "2.0"
    let id: Int?
    let method: String
    let params: JSONValue?
}

/// JSON-RPC response. Notifications have no id and are handled separately.
struct JSONRPCResponse: Decodable, Sendable {
    let jsonrpc: String
    let id: Int?
    let result: JSONValue?
    let error: JSONRPCRemoteError?
}

/// JSON-RPC error payload returned by app-server.
struct JSONRPCRemoteError: Decodable, Sendable, Error {
    let code: Int
    let message: String
    let data: JSONValue?
}

/// Sanitized local transport failures; raw process output is never included.
enum JSONRPCError: LocalizedError, Sendable {
    case invalidMessage
    case transportNotStarted
    case processExited
    case brokenPipe
    case timeout
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidMessage: return "收到无法解析的 app-server 消息"
        case .transportNotStarted: return "app-server 尚未启动"
        case .processExited: return "Codex app-server 已退出"
        case .brokenPipe: return "与 Codex app-server 的连接已断开"
        case .timeout: return "Codex app-server 请求超时"
        case .encodingFailed: return "无法编码 JSON-RPC 请求"
        }
    }
}
