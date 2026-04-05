import Foundation

enum LayoutStyle: String, CaseIterable {
    case classic   // Small Hap (notch width) + panel below
    case expanded  // Hap always at panel width + panel below
}

@Observable
class SettingsManager {
    static let shared = SettingsManager()

    var showNotch: Bool {
        didSet { UserDefaults.standard.set(showNotch, forKey: "replaceNotch") }
    }

    var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled") }
    }

    var xcodeIntegrationEnabled: Bool {
        didSet { UserDefaults.standard.set(xcodeIntegrationEnabled, forKey: "xcodeIntegrationEnabled") }
    }

    var claudeIntegrationEnabled: Bool {
        didSet { UserDefaults.standard.set(claudeIntegrationEnabled, forKey: "claudeIntegrationEnabled") }
    }

    var revealOnHover: Bool {
        didSet { UserDefaults.standard.set(revealOnHover, forKey: "revealOnHover") }
    }

    var layoutStyle: LayoutStyle {
        didSet {
            UserDefaults.standard.set(layoutStyle.rawValue, forKey: "layoutStyle")
            NotificationCenter.default.post(name: .NotchyLayoutStyleChanged, object: nil)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "replaceNotch") == nil { defaults.set(true, forKey: "replaceNotch") }
        if defaults.object(forKey: "soundsEnabled") == nil { defaults.set(true, forKey: "soundsEnabled") }
        if defaults.object(forKey: "xcodeIntegrationEnabled") == nil { defaults.set(true, forKey: "xcodeIntegrationEnabled") }
        if defaults.object(forKey: "claudeIntegrationEnabled") == nil { defaults.set(true, forKey: "claudeIntegrationEnabled") }
        if defaults.object(forKey: "revealOnHover") == nil { defaults.set(true, forKey: "revealOnHover") }
        if defaults.object(forKey: "layoutStyle") == nil { defaults.set(LayoutStyle.expanded.rawValue, forKey: "layoutStyle") }

        showNotch = defaults.bool(forKey: "replaceNotch")
        soundsEnabled = defaults.bool(forKey: "soundsEnabled")
        xcodeIntegrationEnabled = defaults.bool(forKey: "xcodeIntegrationEnabled")
        claudeIntegrationEnabled = defaults.bool(forKey: "claudeIntegrationEnabled")
        revealOnHover = defaults.bool(forKey: "revealOnHover")
        layoutStyle = LayoutStyle(rawValue: defaults.string(forKey: "layoutStyle") ?? "") ?? .classic
    }
}
