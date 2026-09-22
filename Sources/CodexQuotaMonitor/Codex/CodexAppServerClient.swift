import Foundation
import os

/// Errors mapped to user-facing states while keeping process details private.
enum CodexClientError: LocalizedError, Sendable {
    case notInstalled
    case notAuthenticated
    case remote(String)
    case invalidResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "未检测到 Codex CLI"
        case .notAuthenticated: return "Codex 尚未登录"
        case .remote(let message): return message
        case .invalidResponse: return "Codex 返回了无法识别的额度数据"
        case .transport(let error): return error.localizedDescription
        }
    }
}

/// Starts app-server, performs the initialize handshake, and reads quotas.
actor CodexAppServerClient {
    private let resolver: CodexExecutableResolver
    private let transport = JSONRPCTransport()
    private let logger = Logger(subsystem: "CodexQuotaMonitor", category: "app-server")
    private var isInitialized = false

    init(resolver: CodexExecutableResolver) {
        self.resolver = resolver
    }

    func fetchRateLimits() async throws -> [QuotaBucket] {
        do {
            try await ensureReady()
            let response = try await transport.request(method: "account/rateLimits/read")
            if let error = response.error {
                if isAuthenticationError(error) {
                    throw CodexClientError.notAuthenticated
                }
                throw CodexClientError.remote("额度请求失败：\(error.message)")
            }
            guard let result = response.result else {
                throw CodexClientError.invalidResponse
            }

            let buckets = RateLimitParser.parse(result: result)
            logger.debug("rate limit refresh succeeded")
            return buckets
        } catch let error as CodexClientError {
            await transport.stop()
            isInitialized = false
            logger.error("rate limit refresh failed: \(self.logCategory(for: error), privacy: .public)")
            throw error
        } catch {
            await transport.stop()
            isInitialized = false
            let mapped: CodexClientError = (error as? CodexResolverError) == .notFound
                ? .notInstalled
                : .transport(error)
            logger.error("rate limit refresh failed: \(self.logCategory(for: mapped), privacy: .public)")
            throw mapped
        }
    }

    func stop() async {
        await transport.stop()
        isInitialized = false
    }

    private func ensureReady() async throws {
        guard !isInitialized else { return }
        let executable: URL
        do {
            executable = try resolver.resolve()
        } catch {
            throw CodexClientError.notInstalled
        }

        do {
            try await transport.start(executable: executable)
            logger.debug("app-server started")
            let initialize = JSONValue.object([
                "clientInfo": .object([
                    "name": .string("codex-quota-monitor"),
                    "title": .string("Codex Quota Monitor"),
                    "version": .string("0.1.1")
                ]),
                "capabilities": .object([
                    "experimentalApi": .bool(true)
                ])
            ])
            let response = try await transport.request(method: "initialize", params: initialize)
            if let error = response.error {
                throw CodexClientError.remote("Codex 初始化失败：\(error.message)")
            }
            try await transport.sendNotification(method: "initialized", params: .object([:]))
            isInitialized = true
            logger.debug("initialize succeeded")
        } catch {
            await transport.stop()
            throw error
        }
    }

    private func isAuthenticationError(_ error: JSONRPCRemoteError) -> Bool {
        let text = error.message.lowercased()
        return error.code == 401 || text.contains("auth") || text.contains("login") || text.contains("unauthorized")
    }

    /// Logs only a fixed category so server messages cannot leak credentials.
    private func logCategory(for error: CodexClientError) -> String {
        switch error {
        case .notInstalled: return "codex_not_installed"
        case .notAuthenticated: return "codex_not_authenticated"
        case .remote: return "remote_error"
        case .invalidResponse: return "invalid_response"
        case .transport: return "transport_error"
        }
    }
}
