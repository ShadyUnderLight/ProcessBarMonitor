import Foundation

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false

    private let fileManager = FileManager.default
    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ai.openclaw.ProcessBarMonitor"

    init() {
        refreshState()
    }

    func refreshState() {
        isEnabled = fileManager.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try installLaunchAgent()
        } else {
            try removeLaunchAgent()
        }
        refreshState()
    }

    private var launchAgentURL: URL {
        let dir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        return dir.appendingPathComponent("\(bundleIdentifier).plist")
    }

    private func installLaunchAgent() throws {
        let appBundleURL = Bundle.main.bundleURL
        let executableURL = appBundleURL.appendingPathComponent("Contents/MacOS/ProcessBarMonitor")

        let plist: [String: Any] = [
            "Label": bundleIdentifier,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]

        try fileManager.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private func removeLaunchAgent() throws {
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            try fileManager.removeItem(at: launchAgentURL)
        }
    }
}
