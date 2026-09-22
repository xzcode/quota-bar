import Foundation

/// A small JSON value type lets the client tolerate additive app-server fields.
public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
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

    public func encode(to encoder: Encoder) throws {
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

    public var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    public var doubleValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }
}

/// JSON-RPC request with an optional object parameter payload.
public struct JSONRPCRequest: Encodable, Sendable {
    public let jsonrpc = "2.0"
    public let id: Int?
    public let method: String
    public let params: JSONValue?

    public init(id: Int?, method: String, params: JSONValue?) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC response. Codex CLI 0.152.x omits jsonrpc on responses, so it is
/// optional even though the client still sends the standard request field.
public struct JSONRPCResponse: Decodable, Sendable {
    public let jsonrpc: String?
    public let id: Int?
    public let method: String?
    public let params: JSONValue?
    public let result: JSONValue?
    public let error: JSONRPCRemoteError?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jsonrpc = try container.decodeIfPresent(String.self, forKey: .jsonrpc)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        method = try container.decodeIfPresent(String.self, forKey: .method)
        params = try container.decodeIfPresent(JSONValue.self, forKey: .params)
        result = try container.decodeIfPresent(JSONValue.self, forKey: .result)
        error = try container.decodeIfPresent(JSONRPCRemoteError.self, forKey: .error)
    }

    private enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params, result, error
    }
}

/// JSON-RPC error payload returned by app-server.
public struct JSONRPCRemoteError: Decodable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(Int.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decodeIfPresent(JSONValue.self, forKey: .data)
    }

    private enum CodingKeys: String, CodingKey {
        case code, message, data
    }
}

/// Sanitized local transport failures; raw process output is never included.
public enum JSONRPCError: LocalizedError, Sendable {
    case invalidMessage
    case transportNotStarted
    case processExited
    case brokenPipe
    case timeout
    case encodingFailed

    public var errorDescription: String? {
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
