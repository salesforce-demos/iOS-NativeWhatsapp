import SwiftUI

struct LockScreenButton: View {
    let icon: String
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()

            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                Circle()
                    .fill(.white)
                    .opacity(isPressed ? 1.0 : 0.0)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isPressed ? .black : .white)
                    .shadow(radius: isPressed ? 0 : 2)
            }
            .frame(width: 50, height: 50)
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct LockScreenPreview: View {
    var body: some View {
        ZStack {
            Image("iOS26").resizable().scaledToFill().ignoresSafeArea()

            HStack(spacing: 50) {
                LockScreenButton(icon: "flashlight.off.fill")
                LockScreenButton(icon: "camera.fill")
            }
        }
    }
}

#Preview {
    LockScreenPreview()
}
