import Foundation
import os
import CodexQuotaCore

/// Owns one app-server process and multiplexes line-delimited JSON-RPC calls.
actor JSONRPCTransport {
    private let logger = Logger(subsystem: "CodexQuotaMonitor", category: "transport")
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var errorOutput: FileHandle?
    private var outputBuffer = Data()
    private var nextRequestID = 1
    private var pending: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]

    var onNotification: (@Sendable (String, JSONValue?) -> Void)?

    func start(executable: URL) throws {
        guard process == nil || process?.isRunning == false else { return }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw JSONRPCError.processExited
        }

        self.process = process
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        errorOutput = stderr.fileHandleForReading
        logger.notice("app-server process started")

        // Consume stdout through readiness callbacks instead of an async line
        // iterator. This keeps JSON-RPC responses flowing in a GUI process.
        output?.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                Task { await self?.handleProcessExit() }
                return
            }
            Task { await self?.consumeOutput(data) }
        }

        // Drain stderr byte-by-byte. A progress/status stream may omit
        // newlines; waiting for one can fill the pipe and stall stdout.
        errorOutput?.readabilityHandler = { handle in
            if handle.availableData.isEmpty {
                handle.readabilityHandler = nil
            }
        }
    }

    func stop() {
        output?.readabilityHandler = nil
        errorOutput?.readabilityHandler = nil
        process?.terminate()
        process = nil
        input = nil
        output = nil
        errorOutput = nil
        outputBuffer.removeAll(keepingCapacity: false)
        failPending(with: JSONRPCError.processExited)
    }

    func request(method: String, params: JSONValue? = nil) async throws -> JSONRPCResponse {
        guard process?.isRunning == true else {
            throw JSONRPCError.transportNotStarted
        }

        let id = nextRequestID
        nextRequestID += 1
        let request = JSONRPCRequest(id: id, method: method, params: params)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request) else {
            throw JSONRPCError.encodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            do {
                try writeLine(data)
                logger.notice("sent request id=\(id, privacy: .public) method=\(method, privacy: .public) \(self.protocolShape(for: data), privacy: .public)")
            } catch {
                pending.removeValue(forKey: id)
                continuation.resume(throwing: error)
                return
            }

            Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    return
                }
                await self?.timeout(requestID: id)
            }
        }
    }

    func sendNotification(method: String, params: JSONValue? = nil) throws {
        guard process?.isRunning == true else { throw JSONRPCError.transportNotStarted }
        let request = JSONRPCRequest(id: nil, method: method, params: params)
        guard let data = try? JSONEncoder().encode(request) else {
            throw JSONRPCError.encodingFailed
        }
        try writeLine(data)
        logger.notice("sent notification method=\(method, privacy: .public) \(self.protocolShape(for: data), privacy: .public)")
    }

    private func writeLine(_ data: Data) throws {
        guard let input else { throw JSONRPCError.brokenPipe }
        var line = data
        line.append(0x0A)
        do {
            try input.write(contentsOf: line)
        } catch {
            throw JSONRPCError.brokenPipe
        }
    }

    /// Buffers arbitrary pipe chunks and dispatches complete JSON-RPC lines.
    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let lineData = outputBuffer.subdata(in: outputBuffer.startIndex..<newline)
            outputBuffer.removeSubrange(outputBuffer.startIndex...newline)
            guard let line = String(data: lineData, encoding: .utf8) else {
                logger.error("discarded app-server line: not UTF-8")
                continue
            }
            handleLine(line)
        }
    }

    /// Returns only JSON-RPC envelope keys and the params container type.
    /// Payload values are intentionally excluded from diagnostics.
    private func protocolShape(for data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "shape=invalid"
        }
        let keys = object.keys.sorted().joined(separator: ",")
        let params: String
        if let value = object["params"] {
            if value is NSNull {
                params = "null"
            } else if value is [String: Any] {
                params = "object"
            } else if value is [Any] {
                params = "array"
            } else {
                params = String(describing: type(of: value))
            }
        } else {
            params = "missing"
        }
        return "keys=\(keys) params=\(params)"
    }

    private func handleLine(_ line: String) {
        guard let data = line.data(using: .utf8) else {
            logger.error("discarded app-server line: not UTF-8")
            return
        }

        // Log only top-level keys and scalar protocol metadata. Never log the
        // raw line because result/error payloads can contain sensitive data.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let keys = object.keys.sorted().joined(separator: ",")
            let responseID = (object["id"] as? NSNumber)?.intValue
            let method = object["method"] as? String
            let hasResult = object["result"] != nil
            let hasError = object["error"] != nil
            logger.notice("received app-server message keys=\(keys, privacy: .public) id=\(responseID.map(String.init) ?? "none", privacy: .public) method=\(method ?? "none", privacy: .public) result=\(hasResult, privacy: .public) error=\(hasError, privacy: .public)")
        } else {
            logger.error("discarded app-server line: top-level JSON is not an object")
        }

        guard let response = try? JSONDecoder().decode(JSONRPCResponse.self, from: data) else {
            // Invalid individual messages do not crash the app; the next
            // request will surface a timeout or process error if necessary.
            logger.error("discarded app-server message: JSON-RPC shape is not recognized")
            return
        }

        if let id = response.id, let continuation = pending.removeValue(forKey: id) {
            logger.notice("matched response id=\(id, privacy: .public)")
            continuation.resume(returning: response)
        } else {
            onNotification?(responseErrorMethod(response), response.result)
        }
    }

    private func responseErrorMethod(_ response: JSONRPCResponse) -> String {
        // Notifications have no standard response field. This marker is
        // sufficient for future refresh-trigger handling without assumptions.
        response.method ?? response.error?.message ?? "notification"
    }

    private func timeout(requestID: Int) {
        guard let continuation = pending.removeValue(forKey: requestID) else { return }
        continuation.resume(throwing: JSONRPCError.timeout)
    }

    private func handleProcessExit() {
        guard process != nil else { return }
        output?.readabilityHandler = nil
        errorOutput?.readabilityHandler = nil
        process = nil
        input = nil
        output = nil
        errorOutput = nil
        failPending(with: JSONRPCError.processExited)
    }

    private func failPending(with error: Error) {
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }
}
