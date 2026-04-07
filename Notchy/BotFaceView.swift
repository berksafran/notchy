import SwiftUI

struct BotFaceView: View {
    var state: NotchDisplayState = .idle
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        Image("face")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(faceColor)
            .scaleEffect(state == .working ? (1.0 + (pulse - 1.0) * 0.15) : 1.0)
            .opacity(state == .waitingForInput ? pulse : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = 0.5
                }
            }
            .clipped()
            .shadow(color: faceColor.opacity(0.6), radius: state != .idle ? 5 : 0)
    }

    private var faceColor: Color {
        switch state {
        case .working: return .yellow
        case .waitingForInput: return .yellow
        case .taskCompleted: return .white
        case .idle: return .white
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
