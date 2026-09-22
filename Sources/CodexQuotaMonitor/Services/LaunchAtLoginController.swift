import ServiceManagement

/// Thin wrapper around Apple's login-item API, isolated for testable UI use.
enum LaunchAtLoginController {
    static func register() throws {
        try SMAppService.mainApp.register()
    }

    static func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
