import Foundation

struct LegacyLaunchAgentCleanupResult {
    let removed: Bool
    let messageKey: String?
    let details: String?
}

enum LegacyLaunchAgentCleaner {
    static let legacyLabel = "ai.openclaw.ProcessBarMonitor"

    static func cleanupIfNeeded(
        fileManager: FileManager = .default,
        processRunner: ((String, [String]) throws -> Int32)? = nil
    ) -> LegacyLaunchAgentCleanupResult {
        let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
        guard fileManager.fileExists(atPath: plistPath) else {
            return LegacyLaunchAgentCleanupResult(removed: false, messageKey: nil, details: nil)
        }

        let runner = processRunner ?? runProcess
        do {
            _ = try? runner("/bin/launchctl", ["bootout", "gui/\(getuid())", plistPath])
            try fileManager.removeItem(atPath: plistPath)
            return LegacyLaunchAgentCleanupResult(
                removed: true,
                messageKey: "status.legacy_launch_agent_removed",
                details: nil
            )
        } catch {
            return LegacyLaunchAgentCleanupResult(
                removed: false,
                messageKey: "status.legacy_launch_agent_remove_failed",
                details: error.localizedDescription
            )
        }
    }

    private static func runProcess(_ launchPath: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
