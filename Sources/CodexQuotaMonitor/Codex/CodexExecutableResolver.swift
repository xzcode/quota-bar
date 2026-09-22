import Foundation

/// Finds and validates the user's Codex CLI without reading authentication data.
struct CodexExecutableResolver: Sendable {
    func resolve() throws -> URL {
        let fileManager = FileManager.default
        var candidates: [String] = []

        if let customPath = UserDefaults.standard.string(forKey: SettingsKey.customCodexPath),
           !customPath.isEmpty {
            candidates.append(customPath)
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            NSString(string: "~/.local/bin/codex").expandingTildeInPath
        ])

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            let url = URL(fileURLWithPath: candidate)
            if validateVersion(at: url) { return url }
        }

        if let shellPath = commandPathFromShell(),
           fileManager.isExecutableFile(atPath: shellPath) {
            let url = URL(fileURLWithPath: shellPath)
            if validateVersion(at: url) { return url }
        }

        throw CodexResolverError.notFound
    }

    private func commandPathFromShell() -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v codex"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func validateVersion(at url: URL) -> Bool {
        let process = Process()
        let output = Pipe()
        process.executableURL = url
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

enum CodexResolverError: LocalizedError, Sendable {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "未检测到 Codex CLI"
        }
    }
}
