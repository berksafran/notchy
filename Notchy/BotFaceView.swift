import SwiftUI

struct BotFaceView: View {
    var state: NotchDisplayState = .idle
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        Image("face")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(state == .working ? pulse : 1.0)
            .opacity(state == .waitingForInput ? pulse : 1.0)
            .animation(
                state == .working || state == .waitingForInput 
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear {
                pulse = 1.15
            }
            .clipped()
            .shadow(color: glowColor.opacity(0.6), radius: state != .idle ? 5 : 0)
    }

    private var glowColor: Color {
        switch state {
        case .working: return .blue
        case .waitingForInput: return .yellow
        case .taskCompleted: return .green
        case .idle: return .clear
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BotFaceView(state: .working)
            .frame(width: 40, height: 30)
        BotFaceView(state: .waitingForInput)
            .frame(width: 40, height: 30)
        BotFaceView(state: .taskCompleted)
            .frame(width: 40, height: 30)
    }
    .padding()
    .background(Color.black)
}
