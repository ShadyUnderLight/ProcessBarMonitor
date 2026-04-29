import XCTest
@testable import ProcessBarMonitor

/// Regression tests for MonitorViewModel initialisation and settings migration
/// behaviour (issue #30).
///
/// These tests focus on the initial state that can be verified without
/// triggering async refresh or timer-based work.  The @MainActor constraint
/// means tests must be async and run on the main thread — XCTest handles
/// this via Task { @MainActor in }.
final class MonitorViewModelTests: XCTestCase {

    // MARK: - Default values when no saved settings exist

    @MainActor
    func testDefault_temperatureMode_isHottestCPU() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.temperatureMode, .hottestCPU)
    }

    @MainActor
    func testDefault_menuBarDisplayMode_isCompact() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.menuBarDisplayMode, .compact)
    }

    @MainActor
    func testDefault_statusMessage_isNil() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertNil(vm.statusMessage)
    }

    @MainActor
    func testDefault_processLimit_isValid() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertTrue([5, 8, 12, 20].contains(vm.processLimit),
            "processLimit should be one of the allowed values")
    }

    @MainActor
    func testDefault_processDiagnostics_allZero() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        let diag = vm.processDiagnostics
        XCTAssertEqual(diag.attemptCount, 0)
        XCTAssertEqual(diag.successCount, 0)
        XCTAssertEqual(diag.failureCount, 0)
        XCTAssertNil(diag.lastAttemptAt)
        XCTAssertNil(diag.lastSuccessAt)
        XCTAssertNil(diag.lastFailureAt)
    }

    // MARK: - Settings migration: legacy display-name strings

    @MainActor
    func testMigration_legacyHottestCPUString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("Hottest CPU", forKey: "temperatureMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.temperatureMode, .hottestCPU)
    }

    @MainActor
    func testMigration_legacyAverageCPUString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("Average CPU", forKey: "temperatureMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.temperatureMode, .averageCPU)
    }

    @MainActor
    func testMigration_legacyLabeledString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("Labeled", forKey: "menuBarDisplayMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.menuBarDisplayMode, .labeled)
    }

    @MainActor
    func testMigration_legacyTemperatureFirstString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("Temperature First", forKey: "menuBarDisplayMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.menuBarDisplayMode, .temperatureFirst)
    }

    // MARK: - Settings migration: modern rawValue strings

    @MainActor
    func testMigration_modernHottestCPUString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("hottestCPU", forKey: "temperatureMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.temperatureMode, .hottestCPU)
    }

    @MainActor
    func testMigration_modernCompactString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("compact", forKey: "menuBarDisplayMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.menuBarDisplayMode, .compact)
    }

    // MARK: - Invalid saved values fall back to defaults

    @MainActor
    func testMigration_invalidTemperatureModeFallsBack() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("not a mode", forKey: "temperatureMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.temperatureMode, .hottestCPU, "invalid value should fall back to .hottestCPU")
    }

    @MainActor
    func testMigration_invalidMenuBarDisplayModeFallsBack() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("foobar", forKey: "menuBarDisplayMode")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.menuBarDisplayMode, .compact, "invalid value should fall back to .compact")
    }

    // MARK: - processLimit boundary values

    @MainActor
    func testMigration_validProcessLimit() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(8, forKey: "processLimit")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.processLimit, 8)
    }

    @MainActor
    func testMigration_invalidProcessLimitFallsBack() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(99, forKey: "processLimit")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.processLimit, 5, "invalid processLimit should fall back to 5")
    }

    // MARK: - Refresh rate preset defaults and migration

    @MainActor
    func testDefault_refreshRatePreset_isBalanced() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.refreshRatePreset, .balanced)
    }

    @MainActor
    func testMigration_modernPowerSavingString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("powerSaving", forKey: "refreshRatePreset")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.refreshRatePreset, .powerSaving)
    }

    @MainActor
    func testMigration_modernBalancedString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("balanced", forKey: "refreshRatePreset")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.refreshRatePreset, .balanced)
    }

    @MainActor
    func testMigration_modernRealTimeString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("realTime", forKey: "refreshRatePreset")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.refreshRatePreset, .realTime)
    }

    @MainActor
    func testMigration_legacyPowerSavingString() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("Power Saving", forKey: "refreshRatePreset")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.refreshRatePreset, .powerSaving)
    }

    @MainActor
    func testMigration_invalidRefreshRatePresetFallsBack() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("foobar", forKey: "refreshRatePreset")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.refreshRatePreset, .balanced, "invalid value should fall back to .balanced")
    }

    // MARK: - Display template defaults and migration

    @MainActor
    func testDefault_displayTemplate_isStandard() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .standard)
    }

    @MainActor
    func testMigration_modernMinimalTemplate() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("minimal", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .minimal)
    }

    @MainActor
    func testMigration_modernStandardTemplate() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("standard", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .standard)
    }

    @MainActor
    func testMigration_modernDetailedTemplate() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("detailed", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .detailed)
    }

    @MainActor
    func testMigration_legacyMinimalTemplate() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("Minimal", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .minimal)
    }

    @MainActor
    func testMigration_invalidDisplayTemplateFallsBack() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("foobar", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .standard, "invalid value should fall back to .standard")
    }

    // MARK: - Module visibility defaults and migration

    @MainActor
    func testDefault_moduleVisibility_isDefaultVisibility() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.moduleVisibility, .defaultVisibility)
    }

    @MainActor
    func testMigration_savedModuleVisibility() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(PopupModuleVisibility.sparklines.rawValue, forKey: "moduleVisibility")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.moduleVisibility, .sparklines)
    }

    @MainActor
    func testMigration_allModulesEnabled() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(PopupModuleVisibility.all.rawValue, forKey: "moduleVisibility")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.moduleVisibility, .all)
    }

    @MainActor
    func testMigration_invalidModuleVisibilityFallsBack() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(99, forKey: "moduleVisibility")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.moduleVisibility, .defaultVisibility)
    }

    // MARK: - displayTemplate drives menuBarTitle format

    @MainActor
    func testMenuBarTitle_usesDisplayTemplate_minimal() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("minimal", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .minimal)
    }

    @MainActor
    func testMenuBarTitle_usesDisplayTemplate_standard() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("standard", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .standard)
    }

    @MainActor
    func testMenuBarTitle_usesDisplayTemplate_detailed() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("detailed", forKey: "displayTemplate")
        let vm = MonitorViewModel(defaults: defaults)
        XCTAssertEqual(vm.displayTemplate, .detailed)
    }
}
