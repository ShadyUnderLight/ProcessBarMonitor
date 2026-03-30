import Foundation

enum L10n {
    private static let bundle: Bundle = {
        let moduleBundle = Bundle.module
        let available = Set(moduleBundle.localizations.map { $0.lowercased() })

        for preferred in Locale.preferredLanguages.map({ $0.lowercased() }) {
            let candidates = localizationCandidates(for: preferred)
            for candidate in candidates where available.contains(candidate) {
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

        var candidates: [String] = []
        candidates.append(language)

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
