import Foundation
import os
import CodexQuotaCore

/// Errors mapped to user-facing states while keeping process details private.
enum CodexClientError: LocalizedError, Sendable {
    enum FailureKind: String, Sendable {
        case rpc
        case timeout
        case processExit
        case brokenPipe
        case startup
    }

    case notInstalled
    case notAuthenticated(code: Int?, message: String)
    case appServerStartFailed(message: String, kind: FailureKind)
    case initializeFailed(code: Int?, message: String, kind: FailureKind)
    case rateLimitsReadFailed(code: Int?, message: String, kind: FailureKind)
    case unrecognizedResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "未检测到 Codex CLI"
        case .notAuthenticated(let code, let message):
            return "Codex 未登录\(rpcCodeSuffix(code))：\(message)"
        case .appServerStartFailed(let message, _):
            return "app-server 启动失败：\(message)"
        case .initializeFailed(let code, let message, _):
            return "Codex 初始化失败\(rpcCodeSuffix(code))：\(message)"
        case .rateLimitsReadFailed(let code, let message, _):
            return "额度请求失败\(rpcCodeSuffix(code))：\(message)"
        case .unrecognizedResponse: return "服务器返回结构无法识别"
        case .transport: return "Codex app-server 通信失败"
        }
    }

    private func rpcCodeSuffix(_ code: Int?) -> String {
        code.map { "（错误码 \($0)）" } ?? ""
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
                throw rateLimitsFailure(from: error)
            }
            if response.error?.code == -32600 {
                // Codex CLI 0.152.x still expects a unit/empty parameter for
                // this method. Retry once without params for that schema only.
                logger.debug("rate limit request params rejected; retrying without params")
                do {
                    response = try await transport.request(method: "account/rateLimits/read")
                } catch {
                    throw rateLimitsFailure(from: error)
                }
            }
            if let error = response.error {
                if isAuthenticationError(error) {
                    throw CodexClientError.notAuthenticated(code: error.code, message: CodexDiagnosticRedactor.message(error.message))
                }
                throw CodexClientError.rateLimitsReadFailed(
                    code: error.code,
                    message: CodexDiagnosticRedactor.message(error.message),
                    kind: .rpc
                )
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
            logger.error("rate limit refresh failed: \(self.logDescription(for: error), privacy: .public)")
            throw error
        } catch {
            await transport.stop()
            isInitialized = false
            let mapped: CodexClientError = .transport(error)
            logger.error("rate limit refresh failed: \(self.logDescription(for: mapped), privacy: .public)")
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
            do {
                try await transport.start(executable: executable)
            } catch {
                let details = transportDetails(from: error)
                throw CodexClientError.appServerStartFailed(message: details.message, kind: details.kind)
            }
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
                let details = transportDetails(from: error)
                throw CodexClientError.initializeFailed(code: nil, message: details.message, kind: details.kind)
            }
            if let error = response.error {
                if isAuthenticationError(error) {
                    throw CodexClientError.notAuthenticated(code: error.code, message: CodexDiagnosticRedactor.message(error.message))
                }
                throw CodexClientError.initializeFailed(
                    code: error.code,
                    message: CodexDiagnosticRedactor.message(error.message),
                    kind: .rpc
                )
            }
            do {
                try await transport.sendNotification(method: "initialized", params: .object([:]))
            } catch {
                let details = transportDetails(from: error)
                throw CodexClientError.initializeFailed(code: nil, message: details.message, kind: details.kind)
            }
            isInitialized = true
            logger.debug("initialize succeeded")
        } catch let error as CodexClientError {
            await transport.stop()
            throw error
        } catch {
            await transport.stop()
            let details = transportDetails(from: error)
            throw CodexClientError.appServerStartFailed(message: details.message, kind: details.kind)
        }
    }

    private func isAuthenticationError(_ error: JSONRPCRemoteError) -> Bool {
        let text = error.message.lowercased()
        return error.code == 401 || text.contains("auth") || text.contains("login") || text.contains("unauthorized")
    }

    private func rateLimitsFailure(from error: Error) -> CodexClientError {
        let details = transportDetails(from: error)
        return .rateLimitsReadFailed(code: nil, message: details.message, kind: details.kind)
    }

    private func transportDetails(from error: Error) -> (kind: CodexClientError.FailureKind, message: String) {
        if let error = error as? JSONRPCError {
            switch error {
            case .timeout:
                return (.timeout, "请求超时")
            case .processExited:
                return (.processExit, "app-server 进程已退出")
            case .brokenPipe:
                return (.brokenPipe, "通信管道已断开")
            default:
                return (.rpc, CodexDiagnosticRedactor.message(error.localizedDescription))
            }
        }
        return (.rpc, CodexDiagnosticRedactor.message(error.localizedDescription))
    }

    /// Logs the safe message and code while never logging raw server output.
    private func logDescription(for error: CodexClientError) -> String {
        switch error {
        case .notInstalled: return "codex_not_installed"
        case .notAuthenticated(let code, let message): return "not_authenticated code=\(code.map(String.init) ?? "none") message=\(message)"
        case .appServerStartFailed(let message, let kind): return "app_server_start_failed kind=\(kind.rawValue) message=\(message)"
        case .initializeFailed(let code, let message, let kind): return "initialize_failed kind=\(kind.rawValue) code=\(code.map(String.init) ?? "none") message=\(message)"
        case .rateLimitsReadFailed(let code, let message, let kind): return "rate_limits_read_failed kind=\(kind.rawValue) code=\(code.map(String.init) ?? "none") message=\(message)"
        case .unrecognizedResponse: return "unrecognized_response"
        case .transport: return "transport_error"
        }
    }
}
