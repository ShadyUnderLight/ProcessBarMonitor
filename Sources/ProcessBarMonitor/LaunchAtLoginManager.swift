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
            return "Launch at login requires macOS 13 or later."
        case .requiresApproval:
            return "macOS accepted the login item request, but it may still need approval in System Settings → General → Login Items."
        case .serviceFailure(let underlying):
            return "Could not update the login item: \(underlying)"
        }
    }
}
