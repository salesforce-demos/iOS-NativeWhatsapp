//
//  ChatHeaderView.swift
//  NotificationLiquidGlass
//
//  Created by Andres Marin on 23/02/26.
//

import SwiftUI

// MARK: - ChatHeaderView
// Fila de navegación del chat (debajo del StatusBar que va en el ZStack padre)
struct ChatHeaderView: View {
    @ObservedObject var vm: ChatViewModel
    var onBack: () -> Void
    var onHeaderTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Espacio para que el header quede debajo del StatusBar (70pt)
            Color.clear.frame(height: 70)

            // Fila de navegación
            HStack(spacing: 10) {
                // Botón back
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                // Avatar + nombre + estado
                Button(action: onHeaderTap) {
                    HStack(spacing: 8) {
                        AvatarView(
                            url: vm.contactAvatarURL,
                            text: vm.contactName.isEmpty ? "?" : vm.contactName,
                            size: 36
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(vm.contactName.isEmpty ? "Contacto" : vm.contactName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("online")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Iconos de acción
                HStack(spacing: 16) {
                    Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                        Image(systemName: "video")
                            .font(.system(size: 20))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred() }) {
                        Image(systemName: "phone")
                            .font(.system(size: 20))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color(.systemGray6))
        }
    }
}

// MARK: - AvatarView
struct AvatarView: View {
    let url: URL?
    let text: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.33, green: 0.60, blue: 0.57))
                .frame(width: size, height: size)

            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        initialsView
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        initialsView
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                initialsView
            }
        }
    }

    private var initialsView: some View {
        Text(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1).uppercased())
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(.white)
    }
}
