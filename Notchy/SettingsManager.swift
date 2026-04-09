import AppKit

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
    var preferredScreenID: CGDirectDisplayID? {
        didSet {
            if let id = preferredScreenID {
                UserDefaults.standard.set(id, forKey: Keys.preferredScreenID)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.preferredScreenID)
            }
        }
    }
    var scale: Double {
        didSet { UserDefaults.standard.set(scale, forKey: Keys.scale) }
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
            Keys.preferredScreenID: 0, // 0 means use built-in / default logic
            Keys.scale:            1.0,
        ])

        showNotch                = defaults.bool(forKey: Keys.showNotch)
        soundsEnabled            = defaults.bool(forKey: Keys.soundsEnabled)
        claudeIntegrationEnabled = defaults.bool(forKey: Keys.claudeIntegration)
        revealOnHover            = defaults.bool(forKey: Keys.revealOnHover)
        let savedID = UInt32(defaults.integer(forKey: Keys.preferredScreenID))
        preferredScreenID = savedID == 0 ? nil : savedID
        scale             = defaults.double(forKey: Keys.scale)
        if scale == 0 { scale = 1.0 }
    }

    // MARK: - Keys

    private enum Keys {
        static let showNotch        = "replaceNotch"
        static let soundsEnabled    = "soundsEnabled"
        static let claudeIntegration = "claudeIntegrationEnabled"
        static let revealOnHover    = "revealOnHover"
        static let preferredScreenID = "preferredScreenID"
        static let scale            = "uiScale"
    }
}
