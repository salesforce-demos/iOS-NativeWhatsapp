import SwiftUI

struct WAMediaPreviewView: View {
    let imageURL: URL?
    var aspect: Double?
    let caption: String
    let recipient: String
    var statusBar: StatusBarSettings?
    var onSend: () -> Void
    var onClose: () -> Void

    @ObservedObject private var images = WAImageCache.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                statusBarView

                ZStack(alignment: .top) {
                    GeometryReader { geo in
                        picture(geo.size)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 6)

                    toolbar
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                }

                captionBar
                    .padding(.horizontal, 10)
                    .padding(.top, 12)

                recipientBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
            }
        }
    }

    private var statusBarView: some View {
        StatusBar(
            carrier: statusBar?.carrier ?? "Carrier",
            signalBars: statusBar?.signalBars ?? 4,
            wifiStrength: statusBar?.wifiStrength ?? 3,
            showWifi: statusBar?.showWifi ?? true,
            foregroundColor: .white,
            isLockScreen: false,
            levelBattery: statusBar?.levelBattery ?? 0.3,
            isCharging: statusBar?.isCharging ?? false
        )
        .frame(height: WA.statusBarHeight - 8)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func picture(_ size: CGSize) -> some View {
        if let cached = images.image(for: imageURL) {
            Image(uiImage: cached)
                .resizable()
                .aspectRatio(cached.size, contentMode: fitsInside(cached.size, size) ? .fill : .fit)
        } else {
            ZStack {
                Color.white.opacity(0.06)
                ProgressView().tint(.white)
            }
            .onAppear { images.prefetch([imageURL]) }
        }
    }

    private func fitsInside(_ image: CGSize, _ container: CGSize) -> Bool {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else { return false }
        let scale = container.width / image.width
        return image.height * scale <= container.height * 1.25
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            circleButton(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
            }

            Spacer(minLength: 0)

            HStack(spacing: 9) {
                circleButton {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17))
                        .offset(y: -1)
                }
                circleButton {
                    Text("HD")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color.white, lineWidth: 1.4)
                        )
                }
                circleButton {
                    Image(systemName: "crop.rotate")
                        .font(.system(size: 16))
                }
                circleButton {
                    StickerIcon(size: 16, lineWidth: 1.4, color: .white)
                }
                circleButton {
                    Text("Aa")
                        .font(.system(size: 16, weight: .semibold))
                }
                circleButton {
                    Image(systemName: "pencil")
                        .font(.system(size: 17))
                }
            }
        }
    }

    private func circleButton<Content: View>(
        action: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.42))
                    .frame(width: 38, height: 38)
                content()
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var captionBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 17))
                .foregroundStyle(.white)

            Text(caption.isEmpty ? "Message" : caption)
                .font(.system(size: 17))
                .foregroundStyle(caption.isEmpty ? Color.white.opacity(0.5) : .white)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            oneTimeBadge
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var oneTimeBadge: some View {
        ZStack {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [2.4, 2.6]))
                .frame(width: 21, height: 21)
            Text("1")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
    }

    private var recipientBar: some View {
        HStack(spacing: 12) {
            Text(recipient)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.13))
                .clipShape(Capsule(style: .continuous))

            Spacer(minLength: 0)

            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(WA.green)
                        .frame(width: 48, height: 48)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(45))
                        .offset(x: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
