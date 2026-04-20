import Foundation

enum L10n {
    // Cached once at enum initialization — Localization doesn't change at runtime.
    private static let cachedAvailableLocalizations: Set<String> = {
        Set(Bundle.module.localizations.map { $0.lowercased() })
    }()

    // Cached once — Locale.preferredLanguages is stable for the process lifetime.
    private static let cachedPreferredLanguages: [String] = {
        Locale.preferredLanguages.map { $0.lowercased() }
    }()

    private static let bundle: Bundle = {
        let moduleBundle = Bundle.module

        for preferred in cachedPreferredLanguages {
            for candidate in localizationCandidates(for: preferred) where cachedAvailableLocalizations.contains(candidate) {
                if let path = moduleBundle.path(forResource: candidate, ofType: "lproj"),
                   let localizedBundle = Bundle(path: path) {
                    return localizedBundle
                }
            }
        }

        return moduleBundle
    }()

    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }

    private static func localizationCandidates(for language: String) -> [String] {
        let parts = language.split(separator: "-").map(String.init)
        guard !parts.isEmpty else { return [language] }

        var candidates: [String] = [language]

        if parts.count >= 2 {
            candidates.append(parts[0] + "-" + parts[1])
        }

        candidates.append(parts[0])

        if parts[0] == "zh" {
            if language.contains("hans") {
                candidates.insert("zh-hans", at: 0)
            }
            if language.contains("hant") {
                candidates.insert("zh-hant", at: 0)
            }
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }
}
