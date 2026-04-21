import XCTest
@testable import ProcessBarMonitor

/// Regression tests for localisation candidate chain (issue #30).
/// Verifies the fallback precedence order in L10n.localizationCandidates.
final class LocalizationTests: XCTestCase {

    // MARK: - English variants

    func testLocalizationCandidates_enUS() {
        let got = L10n.localizationCandidatesTest(for: "en-US")
        XCTAssertEqual(got, ["en-US", "en"])
    }

    func testLocalizationCandidates_enGB() {
        let got = L10n.localizationCandidatesTest(for: "en-GB")
        XCTAssertEqual(got, ["en-GB", "en"])
    }

    func testLocalizationCandidates_enAU() {
        let got = L10n.localizationCandidatesTest(for: "en-AU")
        XCTAssertEqual(got, ["en-AU", "en"])
    }

    // MARK: - Chinese variants

    func testLocalizationCandidates_zhHansCN() {
        let got = L10n.localizationCandidatesTest(for: "zh-Hans-CN")
        // Order: zh-Hans-CN (full), zh-Hans (script), zh (language)
        XCTAssertEqual(got, ["zh-Hans-CN", "zh-Hans", "zh"])
    }

    func testLocalizationCandidates_zhHantTW() {
        let got = L10n.localizationCandidatesTest(for: "zh-Hant-TW")
        XCTAssertEqual(got, ["zh-Hant-TW", "zh-Hant", "zh"])
    }

    func testLocalizationCandidates_zhHans() {
        let got = L10n.localizationCandidatesTest(for: "zh-Hans")
        XCTAssertEqual(got, ["zh-Hans", "zh"])
    }

    func testLocalizationCandidates_zhHant() {
        let got = L10n.localizationCandidatesTest(for: "zh-Hant")
        XCTAssertEqual(got, ["zh-Hant", "zh"])
    }

    func testLocalizationCandidates_zh() {
        let got = L10n.localizationCandidatesTest(for: "zh")
        XCTAssertEqual(got, ["zh"])
    }

    // MARK: - Other languages

    func testLocalizationCandidates_de() {
        let got = L10n.localizationCandidatesTest(for: "de")
        XCTAssertEqual(got, ["de"])
    }

    func testLocalizationCandidates_frFR() {
        let got = L10n.localizationCandidatesTest(for: "fr-FR")
        XCTAssertEqual(got, ["fr-FR", "fr"])
    }

    func testLocalizationCandidates_jaJP() {
        let got = L10n.localizationCandidatesTest(for: "ja-JP")
        XCTAssertEqual(got, ["ja-JP", "ja"])
    }

    // MARK: - Deduplication

    func testLocalizationCandidates_noDuplicates() {
        // en-US produces ["en-us", "en"] — no duplicate "en".
        let got = L10n.localizationCandidatesTest(for: "en-US")
        XCTAssertEqual(got.count, Set<String>(got).count, "No duplicate entries expected")
    }

    func testLocalizationCandidates_zhHansCN_noDuplicates() {
        let got = L10n.localizationCandidatesTest(for: "zh-Hans-CN")
        XCTAssertEqual(got.count, Set<String>(got).count, "No duplicate entries expected")
    }

    // MARK: - Language-only input (no region)

    func testLocalizationCandidates_languageOnly() {
        let got = L10n.localizationCandidatesTest(for: "de")
        XCTAssertEqual(got, ["de"])
    }

    // MARK: - Empty / malformed

    func testLocalizationCandidates_emptyString() {
        let got = L10n.localizationCandidatesTest(for: "")
        // Empty string is treated as-is (matches guard clause in implementation).
        XCTAssertEqual(got, [""])
    }
}
