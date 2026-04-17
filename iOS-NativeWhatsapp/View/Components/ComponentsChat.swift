//
//  ComponentsChat.swift
//  NotificationLiquidGlass
//
//  Created by Andres Marin on 13/02/26.
//
import SwiftUI

// MARK: - WhatsApp color constants
private extension Color {
    // Light mode
    static let waBubbleOutLight = Color(red: 0.851, green: 0.992, blue: 0.831)  // #D9FDD4
    static let waBubbleInLight  = Color.white
    // Dark mode
    static let waBubbleOutDark  = Color(red: 0.129, green: 0.314, blue: 0.267)  // #214F44
    static let waBubbleInDark   = Color(red: 0.16, green: 0.16, blue: 0.18)     // #292930
    // Acento
    static let waGreen          = Color(red: 0.067, green: 0.475, blue: 0.424)
    static let waTick           = Color(red: 0.243, green: 0.698, blue: 0.604)
    static let waTickDark       = Color(red: 0.384, green: 0.796, blue: 0.698)
}

// MARK: - MessageBubble
struct MessageBubble: View {
    let message: UIMessage
    var isLastInGroup: Bool = true
    var onOptionSelected: ((MessageOption) -> Void)? = nil

    private var hasImage: Bool { !(message.imageURL ?? "").isEmpty }
    private var hasText: Bool { !message.text.isEmpty }
    private var hasOptions: Bool { !(message.options?.isEmpty ?? true) }
    private var hasContent: Bool { hasImage || hasText || hasOptions }

    var body: some View {
        if hasContent {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isCurrentUser { Spacer(minLength: 52) }

                VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
                    if hasImage {
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

                    // Opciones seleccionables
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
                .frame(maxWidth: 264, alignment: message.isCurrentUser ? .trailing : .leading)

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

// MARK: - WaBubbleWithImage (imagen + texto opcional en una sola burbuja)
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
        let f = DateFormatter(); f.dateFormat = "h:mm a"
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

// MARK: - WaBubble (burbuja individual al estilo WhatsApp)
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

// MARK: - WaBubbleShape (forma WhatsApp con tail)
struct WaBubbleShape: Shape {
    let isCurrentUser: Bool
    let showTail: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 10         // radio esquinas generales
        let rTail: CGFloat = 2      // radio esquina adyacente al tail (casi recta)
        let tailW: CGFloat = 7      // espacio horizontal reservado para el tail
        let tailH: CGFloat = 11     // altura desde la base donde empieza el tail

        var path = Path()

        if isCurrentUser {
            // El rect ya incluye el espacio del tail a la derecha.
            // El cuerpo ocupa [minX ... maxX - tailW], el tail va de [maxX-tailW ... maxX]
            let cR = rect.maxX - (showTail ? tailW : 0)  // borde derecho del cuerpo
            let L = rect.minX, T = rect.minY, B = rect.maxY

            path.move(to: CGPoint(x: L + r, y: T))
            // top edge
            path.addLine(to: CGPoint(x: cR - r, y: T))
            path.addArc(center: CGPoint(x: cR - r, y: T + r), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            // right edge del cuerpo
            if showTail {
                path.addLine(to: CGPoint(x: cR, y: B - tailH - rTail))
                // esquina bottom-right del cuerpo: casi recta
                path.addArc(center: CGPoint(x: cR - rTail, y: B - tailH - rTail), radius: rTail,
                            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                // base horizontal hasta el inicio del tail
                path.addLine(to: CGPoint(x: cR - rTail, y: B - tailH))
                // tail: curva cóncava hacia la punta
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX, y: B),
                    control: CGPoint(x: cR + tailW * 0.1, y: B - tailH * 0.5)
                )
                // cierre del tail volviendo a la base del cuerpo
                path.addLine(to: CGPoint(x: cR, y: B))
            } else {
                path.addLine(to: CGPoint(x: cR, y: B - r))
                path.addArc(center: CGPoint(x: cR - r, y: B - r), radius: r,
                            startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            }
            // bottom edge
            path.addLine(to: CGPoint(x: L + r, y: B))
            path.addArc(center: CGPoint(x: L + r, y: B - r), radius: r,
                        startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            // left edge
            path.addLine(to: CGPoint(x: L, y: T + r))
            path.addArc(center: CGPoint(x: L + r, y: T + r), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        } else {
            // El cuerpo ocupa [minX + tailW ... maxX], el tail va de [minX ... minX+tailW]
            let cL = rect.minX + (showTail ? tailW : 0)  // borde izquierdo del cuerpo
            let R = rect.maxX, T = rect.minY, B = rect.maxY

            path.move(to: CGPoint(x: cL + r, y: T))
            // top edge
            path.addLine(to: CGPoint(x: R - r, y: T))
            path.addArc(center: CGPoint(x: R - r, y: T + r), radius: r,
                        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            // right bottom
            path.addLine(to: CGPoint(x: R, y: B - r))
            path.addArc(center: CGPoint(x: R - r, y: B - r), radius: r,
                        startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

            if showTail {
                // base del cuerpo hasta el inicio del tail
                path.addLine(to: CGPoint(x: cL, y: B))
                // cierre del tail desde la base
                path.addLine(to: CGPoint(x: rect.minX, y: B))
                // tail: curva cóncava hacia arriba hasta la esquina del cuerpo
                path.addQuadCurve(
                    to: CGPoint(x: cL + rTail, y: B - tailH),
                    control: CGPoint(x: cL - tailW * 0.1, y: B - tailH * 0.5)
                )
                // esquina bottom-left del cuerpo: casi recta
                path.addArc(center: CGPoint(x: cL + rTail, y: B - tailH - rTail), radius: rTail,
                            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            } else {
                path.addLine(to: CGPoint(x: cL + r, y: B))
                path.addArc(center: CGPoint(x: cL + r, y: B - r), radius: r,
                            startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            }
            // left edge
            path.addLine(to: CGPoint(x: cL, y: T + r))
            path.addArc(center: CGPoint(x: cL + r, y: T + r), radius: r,
                        startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - MessageOptionView
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

// MARK: - TypingBubbleView (tres puntos estilo WhatsApp)
struct TypingBubbleView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                WaBubbleShape(isCurrentUser: false, showTail: true)
                    .fill(colorScheme == .dark ? Color.waBubbleInDark : Color.waBubbleInLight)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 1, x: 0, y: 1)

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .frame(width: 7, height: 7)
                            .foregroundColor(Color.gray.opacity(0.55))
                            .scaleEffect(isAnimating ? 1.1 : 0.6)
                            .opacity(isAnimating ? 1.0 : 0.35)
                            .animation(
                                Animation.easeInOut(duration: 0.55)
                                    .repeatForever(autoreverses: true)
                                    .delay(0.18 * Double(index)),
                                value: isAnimating
                            )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .padding(.leading, 6)
            }
            .fixedSize()

            Spacer(minLength: 60)
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 1)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Preview
#Preview("Options Preview") {
    let options = [
        MessageOption(text: "$2M - $4M", order: 1, imageURL: "", isSelectable: true, selected: false),
        MessageOption(text: "$4M - $8M", order: 2, imageURL: "", isSelectable: true, selected: false),
        MessageOption(text: "Above $8M", order: 3, imageURL: "", isSelectable: true, selected: false)
    ]
    ScrollView {
        VStack(spacing: 2) {
            // Bot con texto + opciones (estado antes de seleccionar)
            MessageBubble(
                message: UIMessage(text: "Excellent taste! What is your preferred budget range?", isCurrentUser: false, timestamp: Date().addingTimeInterval(-60), options: options)
            )
            // Bot sin opciones (estado después de seleccionar)
            MessageBubble(
                message: UIMessage(text: "Excellent taste! What is your preferred budget range?", isCurrentUser: false, timestamp: Date().addingTimeInterval(-55), options: nil)
            )
            // Usuario con opción seleccionada
            MessageBubble(
                message: UIMessage(text: "$2M - $4M", isCurrentUser: true, timestamp: Date().addingTimeInterval(-50))
            )
            // Texto largo que antes generaba espacio extra
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
