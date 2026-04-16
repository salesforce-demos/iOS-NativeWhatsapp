//
//  RootView.swift
//  NotificationLiquidGlass
//
//  Created by Andres Marin on 13/02/26.
//

import Foundation
import SwiftUI

struct iPhoneSimulatorRoot: View {
    @StateObject private var lockVM = LockScreenViewModel()
    @State private var lockScreenOffset: CGFloat = 0
    @State private var isLocked: Bool = true
    @State private var isConfigured: Bool = false
    @State private var chatServiceURL: String = ""

    @State private var screenHeight: CGFloat = 852

    // progress: 0 = lockscreen en reposo, 1 = completamente desbloqueado
    var progress: Double {
        let p = -lockScreenOffset / screenHeight
        return max(0, min(p, 1))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if !isConfigured {
                    URLConfigurationView(
                        chatServiceURL: $chatServiceURL,
                        isConfigured: $isConfigured
                    )
                    .transition(.opacity)
                    .zIndex(2)
                } else {
                    // App principal — visible solo durante la animación de desbloqueo
                    WhatsAppMainView(isLocked: $isLocked, onLockAction: { lockPhone() })
                        .blur(radius: isLocked ? (1.0 - progress) * 4 : 0)
                        .opacity(isLocked && progress < 0.01 ? 0 : 1)
                        .allowsHitTesting(!isLocked)
                        .zIndex(0)
                        .statusBarHidden(true)

                    // Lockscreen — ocupa toda la pantalla, se desliza hacia arriba al desbloquear
                    if isLocked {
                        LockScreenView(
                            viewModel: lockVM,
                            offset: $lockScreenOffset,
                            opacity: .constant(max(0, 1.0 - progress * 1.5))
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(y: lockScreenOffset)
                        // Corner radius aparece solo al arrastrar
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: progress > 0.01 ? pow(progress, 0.35) * 48 : 0,
                                style: .continuous
                            )
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    if v.translation.height < 0 {
                                        lockScreenOffset = v.translation.height
                                    }
                                }
                                .onEnded { v in
                                    if v.translation.height < -150 || v.velocity.height < -800 {
                                        unlockPhone()
                                    } else {
                                        withAnimation(.interpolatingSpring(stiffness: 250, damping: 25)) {
                                            lockScreenOffset = 0
                                        }
                                    }
                                }
                        )
                        .zIndex(1)
                        .transition(.identity)
                        .statusBarHidden(true)
                        .ignoresSafeArea()
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                screenHeight = geo.size.height
            }
            .onChange(of: geo.size.height) { _, h in
                screenHeight = h
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: "chatServiceURL"), !saved.isEmpty {
                chatServiceURL = saved
            }
        }
        .onChange(of: isConfigured) { _, newValue in
            if newValue {
                NetworkService.shared.baseURL = chatServiceURL
            }
        }
    }

    func unlockPhone() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.interpolatingSpring(stiffness: 180, damping: 20)) {
            lockScreenOffset = -screenHeight
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            isLocked = false
            lockScreenOffset = 0
        }
    }

    func lockPhone() {
        lockScreenOffset = -screenHeight
        isLocked = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 20)) {
                lockScreenOffset = 0
            }
        }
    }
}
