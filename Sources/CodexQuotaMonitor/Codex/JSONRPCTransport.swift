import Foundation
import CodexQuotaCore

/// Owns one app-server process and multiplexes line-delimited JSON-RPC calls.
actor JSONRPCTransport {
    private var process: Process?
    private var input: FileHandle?
    private var readTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?
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

        // Consume both streams continuously so a verbose server cannot block.
        let outputHandle = stdout.fileHandleForReading
        readTask = Task { [weak self] in
            do {
                for try await line in outputHandle.bytes.lines {
                    guard let self else { return }
                    await self.handleLine(String(line))
                }
                await self?.handleProcessExit()
            } catch {
                await self?.handleProcessExit()
            }
        }

        let errorHandle = stderr.fileHandleForReading
        stderrTask = Task<Void, Never> {
            // stderr is intentionally discarded; credentials or server output
            // must never accidentally enter the application's logs.
            do {
                for try await _ in errorHandle.bytes.lines { }
            } catch {
                // The stream can end normally when app-server exits.
            }
        }
    }

    func stop() {
        readTask?.cancel()
        stderrTask?.cancel()
        readTask = nil
        stderrTask = nil
        process?.terminate()
        process = nil
        input = nil
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

    private func handleLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let response = try? JSONDecoder().decode(JSONRPCResponse.self, from: data) else {
            // Invalid individual messages do not crash the app; the next
            // request will surface a timeout or process error if necessary.
            return
        }

        if let id = response.id, let continuation = pending.removeValue(forKey: id) {
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
        process = nil
        input = nil
        failPending(with: JSONRPCError.processExited)
    }

    private func failPending(with error: Error) {
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
    }
}
