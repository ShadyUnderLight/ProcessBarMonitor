import XCTest
@testable import ProcessBarMonitor

// MARK: - Test-access wrappers for private implementation details
//
// These extensions expose private members to the test target so that
// regression tests can directly verify implementation behaviour without
// compromising the public API.

extension L10n {
    /// Test-only wrapper exposing the private localisationCandidates chain.
    static func localizationCandidatesTest(for language: String) -> [String] {
        localizationCandidates(for: language)
    }
}
