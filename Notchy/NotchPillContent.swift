import AppKit
import SwiftUI

// MARK: - Notch pill SwiftUI content

/// The SwiftUI view rendered inside the floating notch pill window.
/// Shows status indicators when Claude is working, and action buttons on hover.
struct NotchPillContent: View {

    // Access @Observable singletons directly so SwiftUI's observation tracking
    // registers dependencies during body evaluation — same pattern used throughout the app.
    private var pillModel = NotchPillModel.shared
    private var store     = SessionStore.shared
    private var settings  = SettingsManager.shared

    private var displayState: NotchDisplayState {
        guard settings.claudeIntegrationEnabled else { return .idle }
        if store.sessions.contains(where: { $0.terminalStatus == .taskCompleted })   { return .taskCompleted }
        if store.sessions.contains(where: { $0.terminalStatus == .waitingForInput }) { return .waitingForInput }
        if store.sessions.contains(where: { $0.terminalStatus == .working })         { return .working }
        return .idle
    }

    var body: some View {
        let isHovering = pillModel.isHovering

        ZStack {
            HStack(spacing: 0) {
                leftActions(isHovering: isHovering)
                Spacer()
                rightContent(isHovering: isHovering)
            }
            .padding(.horizontal, 16 + (isHovering ? 4 : 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: displayState)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .offset(y: isHovering ? -3 : -2)
        .onChange(of: displayState) {
            NotificationCenter.default.post(name: .NotchyNotchStatusChanged, object: nil)
        }
    }

    // MARK: - Left side (Terminal, Settings, Debug)

    @ViewBuilder
    private func leftActions(isHovering: Bool) -> some View {
        if isHovering {
            HStack(spacing: 14) {
                iconButton(icon: "apple.terminal", isActive: store.activeTab == .terminal) {
                    store.activeTab = .terminal
                    NotificationCenter.default.post(name: .NotchyExpandPanel, object: nil)
                }

                iconButton(icon: "gear", isActive: store.activeTab == .settings) {
                    store.activeTab = .settings
                    NotificationCenter.default.post(name: .NotchyExpandPanel, object: nil)
                }

                // Temporary debug: force taskCompleted on the active session
                iconButton(icon: "flask", isActive: false) {
                    if let id = store.activeSessionId {
                        store.updateTerminalStatus(id, status: .taskCompleted)
                    }
                }
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    // MARK: - Right side (Status indicator, Bot face, Pin, Quit)

    @ViewBuilder
    private func rightContent(isHovering: Bool) -> some View {
        HStack(spacing: 14) {
            statusContent(isHovering: isHovering)

            if isHovering {
                pinButton
                quitButton
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private func statusContent(isHovering: Bool) -> some View {
        if displayState != .idle {
            statusIndicator
            botFace(state: displayState)
        } else if !isHovering {
            botFace(state: .taskCompleted)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch displayState {
        case .taskCompleted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.green)
        case .waitingForInput:
            ReadyIndicatorView()
                .frame(width: 14, height: 14)
        case .working:
            WorkingIndicatorView()
                .frame(width: 14, height: 14)
        case .idle:
            EmptyView()
        }
    }

    private func botFace(state: NotchDisplayState) -> some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(width: 18, height: 18)
            .overlay(alignment: .trailing) {
                BotFaceView(state: state)
                    .frame(width: 20, height: 15)
                    .mask(RoundedRectangle(cornerRadius: 5))
            }
    }

    private var pinButton: some View {
        Button(action: { store.isPinned.toggle() }) {
            Image(systemName: store.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }

    private var quitButton: some View {
        Button(action: { NSApp.terminate(nil) }) {
            Image(systemName: "power")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func iconButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isActive ? .accentColor : .white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status indicator views

struct ReadyIndicatorView: View {
    var body: some View {
        Circle()
            .fill(Color.black)
            .frame(width: 10, height: 10)
    }
}

struct WorkingIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 10, height: 10)
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

// MARK: - Preview

#Preview("Notch İçeriği") {
    NotchPillContent()
        .frame(width: 180, height: 37)
        .background(Color.black)
}
