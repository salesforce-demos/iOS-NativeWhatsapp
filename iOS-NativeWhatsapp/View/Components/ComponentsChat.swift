import SwiftUI

private extension Color {
    static let waBubbleOutLight = Color(red: 0.851, green: 0.992, blue: 0.831)
    static let waBubbleInLight  = Color.white
    static let waBubbleOutDark  = Color(red: 0.129, green: 0.314, blue: 0.267)
    static let waBubbleInDark   = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let waGreen          = Color(red: 0.067, green: 0.475, blue: 0.424)
    static let waTick           = Color(red: 0.243, green: 0.698, blue: 0.604)
    static let waTickDark       = Color(red: 0.384, green: 0.796, blue: 0.698)
}

struct WADateSeparator: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(WA.datePill))
            .frame(maxWidth: .infinity)
    }
}

struct WAEncryptionNotice: View {
    var body: some View {
        (
            Text(Image(systemName: "lock.fill")).font(.system(size: 11))
            + Text(" Messages and calls are end-to-end encrypted. Only people in this chat can read, listen to, or share them. ")
            + Text("Learn more").fontWeight(.semibold)
        )
        .font(.system(size: 12))
        .foregroundStyle(WA.noticeText)
        .lineSpacing(4.5)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 7.5)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(WA.noticeBg)
        )
        .padding(.horizontal, 54)
        .padding(.top, 11)
    }
}


struct WaChecklistBubble: View {
    let text: String
    let items: [String]
    let timestamp: Date

    @State private var shown = 0

    private var timeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(.displayP3, red: 0.86, green: 0.96, blue: 0.89))
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(.displayP3, red: 0.13, green: 0.60, blue: 0.33))
                        }
                        Text(item)
                            .font(.system(size: 15))
                            .foregroundColor(.black.opacity(0.75))
                    }
                    .opacity(index < shown ? 1 : 0)
                    .scaleEffect(index < shown ? 1 : 0.85, anchor: .leading)
                    .offset(y: index < shown ? 0 : 6)
                }
            }

            HStack {
                Spacer()
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.42))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        )
        .onAppear { revealNext() }
    }

    private func revealNext() {
        guard shown < items.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(shown) * 0.28) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { shown += 1 }
            revealNext()
        }
    }
}

struct WaAssetBubble: View {
    let assetName: String
    let text: String?
    let buttons: [MessageButton]?
    let timestamp: Date
    let isCurrentUser: Bool

    private var timeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }

    private var bubbleColor: Color {
        isCurrentUser ? Color(red: 0.851, green: 0.992, blue: 0.831) : .white
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)

            if let text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
            }

            if let buttons, !buttons.isEmpty {
                VStack(spacing: 0) {
                    ForEach(buttons) { button in
                        Divider().opacity(0.35)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 8) {
                                if let icon = button.icon, !icon.isEmpty {
                                    Image(systemName: icon)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(button.title ?? "")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(Color(.displayP3, red: 0.05, green: 0.40, blue: 0.92))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(WaCardButtonStyle())
                    }
                }
            }

            HStack {
                Spacer()
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.42))
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bubbleColor)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct WaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.05) : Color.clear)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct MessageBubble: View {
    let message: UIMessage
    var isLastInGroup: Bool = true
    var onOptionSelected: ((MessageOption) -> Void)? = nil

    private var hasImage: Bool { !(message.imageURL ?? "").isEmpty }
    private var hasAsset: Bool { !(message.assetName ?? "").isEmpty }
    private var hasText: Bool { !message.text.isEmpty }
    private var hasOptions: Bool { !(message.options?.isEmpty ?? true) }
    private var hasContent: Bool { hasImage || hasAsset || hasText || hasOptions }

    var body: some View {
        if hasContent {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isCurrentUser { Spacer(minLength: 52) }

                VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
                    if hasAsset {
                        WaAssetBubble(
                            assetName: message.assetName ?? "",
                            text: hasText ? message.text : nil,
                            buttons: message.buttons,
                            timestamp: message.timestamp,
                            isCurrentUser: message.isCurrentUser
                        )
                    } else if message.component == "checklist" {
                        WaChecklistBubble(
                            text: message.text,
                            items: message.items ?? [],
                            timestamp: message.timestamp
                        )
                    } else if hasImage {
                        WaBubbleWithImage(
                            imageURL: resolveImageURL(rawPath: message.imageURL ?? ""),
                            text: hasText ? message.text : nil,
                            timestamp: message.timestamp,
                            isCurrentUser: message.isCurrentUser
                        )
                    } else if hasText {
                        WaBubble(
                            text: message.text,
                            timestamp: message.timestamp,
                            isCurrentUser: message.isCurrentUser,
                            showTail: false
                        )
                    }

                    if hasOptions, let options = message.options {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(options) { option in
                                MessageOptionView(option: option) {
                                    onOptionSelected?(option)
                                }
                            }
                        }
                        .padding(.top, hasText || hasImage ? 4 : 0)
                    }
                }
                .frame(maxWidth: hasAsset ? 300 : 264, alignment: message.isCurrentUser ? .trailing : .leading)

                if !message.isCurrentUser { Spacer(minLength: 52) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
    }

    private func resolveImageURL(rawPath: String) -> URL? {
        if rawPath.hasPrefix("http") { return URL(string: rawPath) }
        var cleanPath = rawPath
        if cleanPath.hasPrefix("..") { cleanPath = String(cleanPath.dropFirst(2)) }
        if !cleanPath.hasPrefix("/") { cleanPath = "/" + cleanPath }
        let baseURL = NetworkService.shared.baseURL
        if let url = URL(string: baseURL) {
            let scheme = url.scheme ?? "https"
            let host = url.host ?? ""
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            var basePath = ""
            for component in pathComponents {
                if component.lowercased() == "resource" || component.contains(".json") { break }
                basePath += "/\(component)"
            }
            return URL(string: "\(scheme)://\(host)\(basePath)\(cleanPath)")
        }
        return URL(string: rawPath)
    }
}

private struct WaBubbleWithImage: View {
    let imageURL: URL?
    let text: String?
    let timestamp: Date
    let isCurrentUser: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var bubbleColor: Color {
        isCurrentUser
            ? (colorScheme == .dark ? .waBubbleOutDark : .waBubbleOutLight)
            : (colorScheme == .dark ? .waBubbleInDark : .waBubbleInLight)
    }
    private var textColor: Color {
        colorScheme == .dark ? .white.opacity(0.92) : .black.opacity(0.85)
    }
    private var timeColor: Color {
        colorScheme == .dark ? .white.opacity(0.38) : .black.opacity(0.42)
    }
    private var tickColor: Color {
        colorScheme == .dark ? .waTickDark : .waTick
    }
    private var timeString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    Color.gray.opacity(0.15).frame(width: 220, height: 160)
                case .success(let image):
                    image.resizable().scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .clipped()
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 40)).foregroundColor(.gray)
                        .frame(width: 220, height: 160)
                        .background(Color.gray.opacity(0.15))
                @unknown default: EmptyView()
                }
            }

            if let text, !text.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(text)
                        .font(.system(size: 16))
                        .foregroundColor(textColor)
                        .frame(maxWidth: 220, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 3) {
                        Text(timeString)
                            .font(.system(size: 11))
                            .foregroundColor(timeColor)
                        if isCurrentUser {
                            ZStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(tickColor)
                                    .offset(x: -4)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(tickColor)
                                    .offset(x: 2)
                            }
                            .frame(width: 18, height: 12)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 3) {
                    Text(timeString)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                    if isCurrentUser {
                        ZStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .offset(x: -4)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .offset(x: 2)
                        }
                        .frame(width: 18, height: 12)
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(6)
            }
        }
        .frame(maxWidth: 220)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bubbleColor)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 1, x: 0, y: 1)
        )
    }
}

private struct WaBubble: View {
    let text: String
    let timestamp: Date
    let isCurrentUser: Bool
    let showTail: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var bubbleColor: Color {
        if isCurrentUser {
            return colorScheme == .dark ? .waBubbleOutDark : .waBubbleOutLight
        } else {
            return colorScheme == .dark ? .waBubbleInDark : .waBubbleInLight
        }
    }

    private var textColor: Color {
        colorScheme == .dark ? .white.opacity(0.92) : .black.opacity(0.85)
    }

    private var timeColor: Color {
        colorScheme == .dark ? .white.opacity(0.38) : .black.opacity(0.42)
    }

    private var tickColor: Color {
        colorScheme == .dark ? .waTickDark : .waTick
    }

    private var timeString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }

    private var metaView: some View {
        HStack(spacing: 3) {
            Text(timeString)
                .font(.system(size: 11))
                .foregroundColor(timeColor)
            if isCurrentUser {
                ZStack {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tickColor)
                        .offset(x: -4)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tickColor)
                        .offset(x: 2)
                }
                .frame(width: 18, height: 12)
            }
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            metaView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bubbleColor)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 1, x: 0, y: 1)
        )
    }
}

struct WaBubbleShape: Shape {
    let isCurrentUser: Bool
    let showTail: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 10
        let rTail: CGFloat = 2
        let tailW: CGFloat = 7
        let tailH: CGFloat = 11

        var path = Path()

        if isCurrentUser {
            let cR = rect.maxX - (showTail ? tailW : 0)
            let L = rect.minX, T = rect.minY, B = rect.maxY

            path.move(to: CGPoint(x: L + r, y: T))
            path.addLine(to: CGPoint(x: cR - r, y: T))
            path.addArc(center: CGPoint(x: cR - r, y: T + r), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            if showTail {
                path.addLine(to: CGPoint(x: cR, y: B - tailH - rTail))
                path.addArc(center: CGPoint(x: cR - rTail, y: B - tailH - rTail), radius: rTail,
                            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                path.addLine(to: CGPoint(x: cR - rTail, y: B - tailH))
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: B),
                    control: CGPoint(x: cR + tailW * 0.1, y: B - tailH * 0.5)
                )
                path.addLine(to: CGPoint(x: cR, y: B))
            } else {
                path.addLine(to: CGPoint(x: cR, y: B - r))
                path.addArc(center: CGPoint(x: cR - r, y: B - r), radius: r,
                            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            }
            path.addLine(to: CGPoint(x: L + r, y: B))
            path.addArc(center: CGPoint(x: L + r, y: B - r), radius: r,
                        startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: L, y: T + r))
            path.addArc(center: CGPoint(x: L + r, y: T + r), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            let cL = rect.minX + (showTail ? tailW : 0)
            let R = rect.maxX, T = rect.minY, B = rect.maxY

            path.move(to: CGPoint(x: cL + r, y: T))
            path.addLine(to: CGPoint(x: R - r, y: T))
            path.addArc(center: CGPoint(x: R - r, y: T + r), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: R, y: B - r))
            path.addArc(center: CGPoint(x: R - r, y: B - r), radius: r,
                        startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

            if showTail {
                path.addLine(to: CGPoint(x: cL, y: B))
                path.addLine(to: CGPoint(x: rect.minX, y: B))
                path.addQuadCurve(
                    to: CGPoint(x: cL + rTail, y: B - tailH),
                    control: CGPoint(x: cL - tailW * 0.1, y: B - tailH * 0.5)
                )
                path.addArc(center: CGPoint(x: cL + rTail, y: B - tailH - rTail), radius: rTail,
                            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            } else {
                path.addLine(to: CGPoint(x: cL + r, y: B))
                path.addArc(center: CGPoint(x: cL + r, y: B - r), radius: r,
                            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            }
            path.addLine(to: CGPoint(x: cL, y: T + r))
            path.addArc(center: CGPoint(x: cL + r, y: T + r), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}

struct MessageOptionView: View {
    let option: MessageOption
    let onTap: () -> Void
    @State private var isSelected = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            if option.isSelectable == true {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isSelected.toggle()
                    onTap()
                }
            }
        }) {
            HStack(spacing: 10) {
                if let imageURL = option.imageURL, !imageURL.isEmpty {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                                .frame(width: 38, height: 38)
                                .cornerRadius(6)
                        default:
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 38, height: 38)
                        }
                    }
                }

                Text(option.displayText)
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.85)))
                    .fixedSize(horizontal: false, vertical: true)

                if option.isSelectable == true {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .white : .waTick)
                        .font(.system(size: 18))
                }
            }
            .frame(width: 240)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? Color.waTick
                          : (colorScheme == .dark ? Color(red: 0.22, green: 0.22, blue: 0.24) : Color.white))
                    .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TypingBubbleView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.55)
                        .opacity(animating ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(0.16 * Double(index)),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .onAppear { animating = true }
    }
}

#Preview("Options Preview") {
    let options = [
        MessageOption(text: "$2M - $4M", order: 1, imageURL: "", isSelectable: true, selected: false),
        MessageOption(text: "$4M - $8M", order: 2, imageURL: "", isSelectable: true, selected: false),
        MessageOption(text: "Above $8M", order: 3, imageURL: "", isSelectable: true, selected: false)
    ]
    ScrollView {
        VStack(spacing: 2) {
            MessageBubble(
                message: UIMessage(text: "Excellent taste! What is your preferred budget range?", isCurrentUser: false, timestamp: Date().addingTimeInterval(-60), options: options)
            )
            MessageBubble(
                message: UIMessage(text: "Excellent taste! What is your preferred budget range?", isCurrentUser: false, timestamp: Date().addingTimeInterval(-55), options: nil)
            )
            MessageBubble(
                message: UIMessage(text: "$2M - $4M", isCurrentUser: true, timestamp: Date().addingTimeInterval(-50))
            )
            MessageBubble(
                message: UIMessage(text: "Gili Lankanfushi — Crusoe Residence", isCurrentUser: true, timestamp: Date().addingTimeInterval(-40))
            )
        }
        .padding(.vertical, 12)
    }
    .background(Color(.systemBackground))
}

#Preview("MessageBubble Preview") {
    ScrollView {
        VStack(spacing: 2) {
            MessageBubble(
                message: UIMessage(text: "Hola!", isCurrentUser: false, timestamp: Date().addingTimeInterval(-300)),
                isLastInGroup: false
            )
            MessageBubble(
                message: UIMessage(text: "¿Cómo estás?", isCurrentUser: false, timestamp: Date().addingTimeInterval(-295))
            )
            MessageBubble(
                message: UIMessage(text: "Muy bien gracias! Todo saliendo perfecto por acá.", isCurrentUser: true, timestamp: Date().addingTimeInterval(-200))
            )
            MessageBubble(
                message: UIMessage(text: "Qué bueno escucharlo", isCurrentUser: false, timestamp: Date().addingTimeInterval(-100)),
                isLastInGroup: false
            )
            MessageBubble(
                message: UIMessage(text: "Te mando la imagen que me pediste.", isCurrentUser: false, timestamp: Date().addingTimeInterval(-90)),
                isLastInGroup: true
            )
            TypingBubbleView().padding(.top, 8)
        }
        .padding(.vertical, 12)
    }
    .background(Color(.systemBackground))
}
