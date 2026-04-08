import Foundation

// MARK: - SettingsManager

/// Persists and exposes all user-configurable settings via `UserDefaults`.
///
/// Each property uses a `didSet` to write to `UserDefaults` immediately on change.
/// Default values are set in `init` if no prior value exists.
@Observable
class SettingsManager {
    static let shared = SettingsManager()

    // MARK: Properties

    var showNotch: Bool {
        didSet { UserDefaults.standard.set(showNotch, forKey: Keys.showNotch) }
    }
    var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: Keys.soundsEnabled) }
    }
    var claudeIntegrationEnabled: Bool {
        didSet { UserDefaults.standard.set(claudeIntegrationEnabled, forKey: Keys.claudeIntegration) }
    }
    var revealOnHover: Bool {
        didSet { UserDefaults.standard.set(revealOnHover, forKey: Keys.revealOnHover) }
    }

    // MARK: Init

    init() {
        let defaults = UserDefaults.standard
        // Register factory defaults — only applied if the key has never been set.
        defaults.register(defaults: [
            Keys.showNotch:        true,
            Keys.soundsEnabled:    true,
            Keys.claudeIntegration: true,
            Keys.revealOnHover:    true,
        ])

        showNotch                = defaults.bool(forKey: Keys.showNotch)
        soundsEnabled            = defaults.bool(forKey: Keys.soundsEnabled)
        claudeIntegrationEnabled = defaults.bool(forKey: Keys.claudeIntegration)
        revealOnHover            = defaults.bool(forKey: Keys.revealOnHover)
    }

    // MARK: - Keys

    private enum Keys {
        static let showNotch        = "replaceNotch"
        static let soundsEnabled    = "soundsEnabled"
        static let claudeIntegration = "claudeIntegrationEnabled"
        static let revealOnHover    = "revealOnHover"
    }
}
