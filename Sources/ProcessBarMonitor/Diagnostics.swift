import Foundation

struct ProcessSnapshotDiagnostics {
    var attemptCount: Int = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var lastAttemptAt: Date?
    var lastSuccessAt: Date?
    var lastFailureAt: Date?
    var lastFailureMessage: String?
    var lastFailureDetails: String?
    var lastSnapshotProcessCount: Int = 0
    var lastTopCPUCount: Int = 0
    var lastTopMemoryCount: Int = 0

    mutating func markAttempt(at date: Date = Date()) {
        attemptCount += 1
        lastAttemptAt = date
    }

    mutating func markSuccess(
        processCount: Int,
        topCPUCount: Int,
        topMemoryCount: Int,
        at date: Date = Date()
    ) {
        successCount += 1
        lastSuccessAt = date
        lastSnapshotProcessCount = processCount
        lastTopCPUCount = topCPUCount
        lastTopMemoryCount = topMemoryCount
    }

    mutating func markFailure(message: String, details: String, at date: Date = Date()) {
        failureCount += 1
        lastFailureAt = date
        lastFailureMessage = message
        lastFailureDetails = details
    }
}
