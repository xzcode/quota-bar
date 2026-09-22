import Foundation
import os
import CodexQuotaCore

/// Errors mapped to user-facing states while keeping process details private.
enum CodexClientError: LocalizedError, Sendable {
    case notInstalled
    case notAuthenticated
    case appServerStartFailed
    case initializeFailed
    case rateLimitsReadFailed
    case unrecognizedResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "未检测到 Codex CLI"
        case .notAuthenticated: return "Codex 尚未登录"
        case .appServerStartFailed: return "app-server 启动失败"
        case .initializeFailed: return "Codex 初始化握手失败"
        case .rateLimitsReadFailed: return "额度请求失败"
        case .unrecognizedResponse: return "服务器返回结构无法识别"
        case .transport: return "Codex app-server 通信失败"
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
            var response: JSONRPCResponse
            do {
                // Reset-credit details are not needed by the quota card and
                // would add unnecessary response data to every refresh.
                response = try await transport.request(
                    method: "account/rateLimits/read",
                    params: .object(["excludeResetCreditDetails": .bool(true)])
                )
            } catch {
                throw CodexClientError.rateLimitsReadFailed
            }
            if response.error?.code == -32600 {
                // Codex CLI 0.152.x still expects a unit/empty parameter for
                // this method. Retry once without params for that schema only.
                logger.debug("rate limit request params rejected; retrying without params")
                do {
                    response = try await transport.request(method: "account/rateLimits/read")
                } catch {
                    throw CodexClientError.rateLimitsReadFailed
                }
            }
            if let error = response.error {
                if isAuthenticationError(error) {
                    throw CodexClientError.notAuthenticated
                }
                throw CodexClientError.rateLimitsReadFailed
            }
            guard let result = response.result else {
                throw CodexClientError.unrecognizedResponse
            }

            let parsed = RateLimitParser.parseDetailed(result: result)
            logger.debug("rate limit response diagnostic: \(parsed.diagnostic.summary, privacy: .public)")
            if parsed.buckets.isEmpty && !parsed.diagnostic.hasRecognizedRateLimitKeys && parsed.diagnostic.source == .none {
                throw CodexClientError.unrecognizedResponse
            }

            let buckets = parsed.buckets
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
            let mapped: CodexClientError = .transport(error)
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
            let response: JSONRPCResponse
            do {
                response = try await transport.request(method: "initialize", params: initialize)
            } catch {
                throw CodexClientError.initializeFailed
            }
            if let error = response.error {
                if isAuthenticationError(error) {
                    throw CodexClientError.notAuthenticated
                }
                throw CodexClientError.initializeFailed
            }
            do {
                try await transport.sendNotification(method: "initialized", params: .object([:]))
            } catch {
                throw CodexClientError.initializeFailed
            }
            isInitialized = true
            logger.debug("initialize succeeded")
        } catch let error as CodexClientError {
            await transport.stop()
            throw error
        } catch {
            await transport.stop()
            throw CodexClientError.appServerStartFailed
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
        case .appServerStartFailed: return "app_server_start_failed"
        case .initializeFailed: return "initialize_failed"
        case .rateLimitsReadFailed: return "rate_limits_read_failed"
        case .unrecognizedResponse: return "unrecognized_response"
        case .transport: return "transport_error"
        }
    }
}
