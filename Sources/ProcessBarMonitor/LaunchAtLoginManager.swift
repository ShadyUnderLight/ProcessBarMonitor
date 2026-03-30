import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false

    init() {
        refreshState()
    }

    func refreshState() {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                isEnabled = true
            case .requiresApproval, .notFound, .notRegistered:
                isEnabled = false
            @unknown default:
                isEnabled = false
            }
        } else {
            isEnabled = false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw LaunchAtLoginError.unsupportedOS
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            throw LaunchAtLoginError.serviceFailure(underlying: error.localizedDescription)
        }

        refreshState()

        if enabled && !isEnabled {
            throw LaunchAtLoginError.requiresApproval
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case unsupportedOS
    case requiresApproval
    case serviceFailure(underlying: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return L10n.string("error.launch_at_login.unsupported")
        case .requiresApproval:
            return L10n.string("error.launch_at_login.requires_approval")
        case .serviceFailure(let underlying):
            return L10n.format("error.launch_at_login.service_failure", underlying)
        }
    }
}
