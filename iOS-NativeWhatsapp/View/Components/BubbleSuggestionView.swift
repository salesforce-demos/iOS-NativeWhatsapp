//
//  BubbleSuggestionView.swift
//  NotificationLiquidGlass
//
//  Created by Andres Marin on 05/03/26.
//

import SwiftUI

struct BubbleSuggestionView: View {
    let suggestion: String
    let onTap: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    private var waGreen: Color { Color(red: 0.067, green: 0.475, blue: 0.424) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(waGreen)

            Text(suggestion)
                .font(.system(size: 15))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .black.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(waGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colorScheme == .dark
                      ? Color(red: 0.16, green: 0.16, blue: 0.18)
                      : Color.white)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(waGreen.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }
    }
}

// MARK: - Preview
#Preview("Bubble Suggestion") {
    ZStack {
        Color(red: 0.937, green: 0.937, blue: 0.937).ignoresSafeArea()
        VStack {
            Spacer()
            BubbleSuggestionView(
                suggestion: "Hola, ¿cómo estás?",
                onTap: { print("tap") }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 80)
        }
    }
}
