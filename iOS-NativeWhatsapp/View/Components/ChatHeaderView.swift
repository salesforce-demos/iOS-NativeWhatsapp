import SwiftUI

enum WA {
    static func p3(_ hex: UInt32) -> Color {
        Color(
            .displayP3,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    static let chrome       = p3(0xF2F0EB)
    static let wallpaper    = p3(0xF3F0EB)
    static let glassButton  = p3(0xFDFBF5)
    static let noticeBg     = p3(0xFBF0D6)
    static let noticeText   = p3(0x0D0D0D)
    static let datePill     = p3(0xFDFDFC)
    static let fieldStroke  = p3(0xB2B2B2)

    static let green        = p3(0x50A767)
    static let chipFill     = p3(0xDFFBD6)
    static let chipStroke   = p3(0xB2C9AB)
    static let chipText     = p3(0x2D5E40)
    static let hairline     = p3(0xCBCBCB)
    static let divider      = p3(0xE5E5E5)
    static let searchFill   = p3(0xF5F4F4)
    static let secondary    = p3(0x6A6B6B)
    static let subtitle     = p3(0x8A8A8E)
    static let verified     = p3(0x0866FF)

    static let statusBarHeight: CGFloat = 62
    static let navRowHeight: CGFloat = 44
    static let headerBottomPadding: CGFloat = 10
    static var headerHeight: CGFloat { statusBarHeight + navRowHeight + headerBottomPadding }

    static let inputRowHeight: CGFloat = 48
    static let inputFieldHeight: CGFloat = 30
    static let rowAvatarSize: CGFloat = 56
    static let rowTextLeading: CGFloat = 88
}

struct WAStatusBarSlot: View {
    var carrier: String
    var signalBars: Int
    var wifiStrength: Int
    var showWifi: Bool
    var levelBattery: Double
    var isCharging: Bool

    var body: some View {
        StatusBar(
            carrier: carrier,
            signalBars: signalBars,
            wifiStrength: wifiStrength,
            showWifi: showWifi,
            foregroundColor: nil,
            isLockScreen: false,
            levelBattery: levelBattery,
            isCharging: isCharging
        )
        .frame(height: WA.statusBarHeight - 8)
        .padding(.top, 8)
    }
}

struct WAChatWallpaper: View {
    var dimmed: Bool = true

    private var hasAsset: Bool { UIImage(named: "fondoWhatsapp") != nil }

    var body: some View {
        (hasAsset ? Color.white : WA.wallpaper)
            .overlay {
                if hasAsset {
                    Image("fondoWhatsapp")
                        .resizable()
                        .scaledToFill()
                        .opacity(dimmed ? 0.45 : 1.0)
                }
            }
            .clipped()
            .ignoresSafeArea()
    }
}

struct WAGlassCircleButton<Content: View>: View {
    var diameter: CGFloat = 44
    var fill: Color = .white
    var action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 1)
                content
            }
            .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.plain)
    }
}

struct ChatHeaderView: View {
    let title: String
    let subtitle: String
    let avatarURL: URL?
    var backBadge: String? = nil
    var isVerified: Bool = false
    var isLogoAvatar: Bool = false
    var businessName: String? = nil
    var showVideoCall: Bool = false
    var onBack: () -> Void
    var onTitleTap: () -> Void
    var onVideoCall: () -> Void = {}
    var onVoiceCall: () -> Void = {}

    @ViewBuilder
    private var subtitleLine: some View {
        if isVerified {
            HStack(spacing: 5) {
                if let businessName, !businessName.isEmpty {
                    Text(businessName)
                }
                WAVerifiedBadge(size: 12)
                if let businessName, !businessName.isEmpty {
                    Text("·")
                }
                Text(subtitle)
            }
            .font(.system(size: 12))
            .foregroundStyle(WA.subtitle)
            .lineLimit(1)
        } else {
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(WA.subtitle)
                .lineLimit(1)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: WA.statusBarHeight)

            HStack(spacing: 0) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 21, weight: .semibold))
                        if let backBadge {
                            Text(backBadge)
                                .font(.system(size: 17))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)

                Button(action: onTitleTap) {
                    HStack(spacing: 12) {
                        AvatarView(
                            url: avatarURL,
                            text: title.isEmpty ? "?" : title,
                            size: 40,
                            isLogo: isLogoAvatar
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            Text(title.isEmpty ? "Contact" : title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                                .lineLimit(1)

                            subtitleLine
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 9)

                Spacer(minLength: 8)

                HStack(spacing: 0) {
                    if showVideoCall {
                        Button(action: onVideoCall) {
                            Image(systemName: "video")
                                .font(.system(size: 23))
                                .foregroundStyle(.black)
                                .frame(width: 55, height: 45)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onVoiceCall) {
                        Image(systemName: "phone")
                            .font(.system(size: 23))
                            .foregroundStyle(.black)
                            .frame(width: showVideoCall ? 55 : 45, height: 45)
                    }
                    .buttonStyle(.plain)
                }
                .background(
                    Capsule()
                        .fill(WA.glassButton)
                        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 1)
                )
                .padding(.trailing, 18)
            }
            .frame(height: WA.navRowHeight)
            .contentShape(Rectangle())
            .onTapGesture { onTitleTap() }

            Color.clear
                .frame(height: WA.headerBottomPadding)
                .contentShape(Rectangle())
                .onTapGesture { onTitleTap() }
        }
        .frame(height: WA.headerHeight)
        .background(WA.chrome)
    }
}

struct StickerGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let r = s * 0.26
        let cut = s * 0.50

        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: s - r, y: 0))
        p.addArc(center: CGPoint(x: s - r, y: r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: s, y: s - cut))
        p.addLine(to: CGPoint(x: s - cut, y: s))
        p.addLine(to: CGPoint(x: r, y: s))
        p.addArc(center: CGPoint(x: r, y: s - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addArc(center: CGPoint(x: r, y: r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()

        p.move(to: CGPoint(x: s, y: s - cut))
        p.addQuadCurve(
            to: CGPoint(x: s - cut, y: s),
            control: CGPoint(x: s - cut * 0.14, y: s - cut * 0.14)
        )
        return p
    }
}

struct StickerIcon: View {
    var size: CGFloat = 17
    var lineWidth: CGFloat = 1.4
    var color: Color = .black

    var body: some View {
        StickerGlyph()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

struct WAVerifiedBadge: View {
    var size: CGFloat = 15

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size))
            .foregroundStyle(WA.verified)
    }
}

struct AvatarView: View {
    let url: URL?
    let text: String
    let size: CGFloat
    var isLogo: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(isLogo ? Color.white : Color(red: 0.33, green: 0.60, blue: 0.57))
                .frame(width: size, height: size)

            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        initialsView
                    case .success(let image):
                        if isLogo {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(size * 0.12)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        } else {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        }
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

#Preview("Header") {
    VStack(spacing: 0) {
        ChatHeaderView(
            title: "Andrés Marín (You)",
            subtitle: "Message yourself",
            avatarURL: nil,
            backBadge: "5",
            isVerified: true,
            onBack: {},
            onTitleTap: {}
        )
        WA.wallpaper
    }
    .ignoresSafeArea()
}
