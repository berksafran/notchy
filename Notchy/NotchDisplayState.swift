import SwiftUI

// MARK: - Notch display state

/// The current display state of the notch bar, derived from all active sessions.
///
/// Hierarchy (highest wins): `.taskCompleted` > `.waitingForInput` > `.working` > `.idle`
enum NotchDisplayState: Equatable {
    case idle
    case working
    case waitingForInput
    case taskCompleted

    static var current: NotchDisplayState {
        guard SettingsManager.shared.claudeIntegrationEnabled else { return .idle }
        let sessions = SessionStore.shared.sessions
        if sessions.contains(where: { $0.terminalStatus == .taskCompleted })    { return .taskCompleted }
        if sessions.contains(where: { $0.terminalStatus == .waitingForInput })  { return .waitingForInput }
        if sessions.contains(where: { $0.terminalStatus == .working })          { return .working }
        return .idle
    }
}

// MARK: - Notch pill model

/// Shared observable model for notch pill hover state.
/// Using a dedicated `@Observable` class ensures SwiftUI reliably tracks changes
/// without needing `@State` or environment injection.
@Observable
class NotchPillModel {
    static let shared = NotchPillModel()
    var isHovering: Bool = false
}
