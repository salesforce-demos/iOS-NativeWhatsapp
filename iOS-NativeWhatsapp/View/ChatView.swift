import SwiftUI

struct ChatView: View {

    @Binding var isLocked: Bool
    var onLockAction: () -> Void

    @StateObject private var vm: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()
    @State private var inputText = ""
    @State private var currentTime = Date()
    @FocusState private var isInputFocused: Bool

    private let hasInjectedConfig: Bool

    init(isLocked: Binding<Bool>, config: ChatConfig? = nil, onLockAction: @escaping () -> Void) {
        self._isLocked = isLocked
        self.onLockAction = onLockAction
        if let config = config {
            self._vm = StateObject(wrappedValue: ChatViewModel(config: config))
            self.hasInjectedConfig = true
        } else {
            self._vm = StateObject(wrappedValue: ChatViewModel())
            self.hasInjectedConfig = false
        }
    }

    private let inputRowHeight: CGFloat = 60
    private let suggestionHeight: CGFloat = 100
    private let extraBottomPadding: CGFloat = 16
    private let headerHeight: CGFloat = 70 + 44

    var body: some View {
        ZStack(alignment: .top) {
            chatContent

            StatusBar(
                carrier: vm.statusBarChatView?.carrier ?? "Carrier",
                signalBars: vm.statusBarChatView?.signalBars ?? 4,
                wifiStrength: vm.statusBarChatView?.wifiStrength ?? 3,
                showWifi: vm.statusBarChatView?.showWifi ?? true,
                foregroundColor: nil,
                isLockScreen: false,
                levelBattery: vm.statusBarChatView?.levelBattery ?? 0.3,
                isCharging: vm.statusBarChatView?.isCharging ?? false
            )
            .frame(height: 70)
            .background(Color(red: 244/255, green: 240/255, blue: 236/255))
        }
        .ignoresSafeArea(edges: .top)
    }
}

private extension ChatView {

    var chatContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                Color(.systemBackground).ignoresSafeArea()

                if let error = vm.errorMessage {
                    errorView(error)
                } else {
                    messageList(geo: geo)
                }

                chatHeader
                    .zIndex(1)

                VStack {
                    Spacer()
                    if vm.isTyping {
                        TypingBubbleView()
                            .padding(.bottom, 4)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                    inputBar
                        .padding(.bottom, keyboard.height > 0
                            ? keyboard.height - geo.safeAreaInsets.bottom
                            : 0)
                }
                .zIndex(2)
                .allowsHitTesting(true)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .navigationBarBackButtonHidden(true)
        .gesture(TapGesture().onEnded { _ in isInputFocused = false })
        .task {
            if !hasInjectedConfig { vm.loadData() }
        }
        .onChange(of: isLocked) { _, locked in
            if locked {
                isInputFocused = false
                vm.resetChat()
            } else {
                if !hasInjectedConfig { vm.loadData() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isInputFocused = true
                }
            }
        }
    }

    var chatHeader: some View {
        VStack(spacing: 0) {
            Color(red: 244/255, green: 240/255, blue: 236/255).frame(height: 70)

            HStack(spacing: 10) {
                Button(action: {
                    isInputFocused = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        onLockAction()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(action: { vm.manualTrigger() }) {
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
            .background(Color(red: 244/255, green: 240/255, blue: 236/255))
        }
        .ignoresSafeArea(edges: .top)
    }

    func errorView(_ error: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(error)
                .multilineTextAlignment(.center)
                .padding()
            Button("Reintentar") { vm.loadData() }
            Spacer()
        }
    }

    func messageList(geo: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                        if shouldShowTimestamp(at: index) {
                            Text(formattedTimestamp(for: msg.timestamp))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }

                        let isLast = isLastInGroup(at: index)
                        MessageBubble(message: msg, isLastInGroup: isLast) { selectedOption in
                            vm.handleOptionSelected(selectedOption)
                        }
                        .id(msg.id)
                    }

                    Color.clear
                        .frame(height: 20)
                        .id("bottom")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                if UIImage(named: "fondoWhatsapp") != nil {
                    Image("fondoWhatsapp")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(0.6)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: headerHeight)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: inputBottomInset(safeBottom: geo.safeAreaInsets.bottom))
            }
            .onChange(of: vm.messages) { oldValue, newValue in
                if newValue.count > oldValue.count {
                    inputText = ""
                }
                scrollToBottom(proxy: proxy, delay: 0.05)
            }
            .onChange(of: vm.isTyping) { _, _ in
                scrollToBottom(proxy: proxy, delay: 0.05)
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    scrollToBottom(proxy: proxy, delay: 0.35)
                }
            }
            .onChange(of: keyboard.height) { oldHeight, newHeight in
                if newHeight > oldHeight {
                    scrollToBottom(proxy: proxy, delay: 0.1)
                }
            }
        }
    }

    var inputBar: some View {
        VStack(spacing: 0) {
            if vm.showSuggestion, let suggestion = vm.currentSuggestion {
                BubbleSuggestionView(
                    suggestion: suggestion,
                    onTap: {
                        inputText = ""
                        vm.applySuggestionAndSend()
                        isInputFocused = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    )
                )
            }

            HStack(alignment: .bottom, spacing: 8) {
                plusButton
                textField
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(red: 244/255, green: 240/255, blue: 236/255).ignoresSafeArea(edges: .bottom))
        .compositingGroup()
        .onAppear {
            if !isLocked {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
    }

    private var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var plusButton: some View {
        Button(action: {}) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    var textField: some View {
        HStack(alignment: .bottom, spacing: 6) {
            HStack(alignment: .bottom, spacing: 0) {
                TextField("", text: $inputText, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .focused($isInputFocused)
                    .font(.system(size: 16))
                    .lineLimit(1...5)
                    .tint(Color(red: 0.0, green: 0.659, blue: 0.518))
                    .padding(.vertical, 10)
                    .padding(.leading, 14)
                    .padding(.trailing, 4)
                    .onChange(of: inputText) { _, newValue in
                        vm.updateSuggestion(for: newValue)
                    }

                Button(action: {}) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 10)
                        .padding(.bottom, 10)
                }
                .buttonStyle(.plain)
                
            }
            .background(Color(.systemBackground))
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color(.systemGray4), lineWidth: 0.8)
            )

            if !hasText {
                Button(action: {}) {
                    Image(systemName: "camera")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            Button(action: {
                guard hasText else { return }
                vm.sendTextMessage(inputText.trimmingCharacters(in: .whitespacesAndNewlines))
                inputText = ""
            }) {
                Image(systemName: hasText ? "paperplane.fill" : "mic")
                    .font(.system(size: 22))
                    .foregroundStyle(hasText ? Color(red: 0.0, green: 0.659, blue: 0.518) : .primary)
                    .frame(width: 36, height: 36)
                    .animation(.easeOut(duration: 0.15), value: hasText)
            }
            .buttonStyle(.plain)
        }
        .animation(.easeOut(duration: 0.15), value: hasText)
    }
}

private extension ChatView {

    func scrollToBottom(proxy: ScrollViewProxy, delay: Double = 0.22) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    func shouldShowTimestamp(at index: Int) -> Bool {
        let messages = vm.messages
        guard index > 0, index < messages.count else { return index == 0 }
        let current = messages[index]
        let previous = messages[index - 1]
        return current.timestamp.timeIntervalSince(previous.timestamp) > 60
    }

    func formattedTimestamp(for date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today' h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: date)
    }

    func isLastInGroup(at index: Int) -> Bool {
        let messages = vm.messages
        guard index < messages.count else { return true }
        let current = messages[index]
        if index == messages.count - 1 { return true }
        let next = messages[index + 1]
        return next.isCurrentUser != current.isCurrentUser
    }

    func inputBottomInset(safeBottom: CGFloat) -> CGFloat {
        let suggestionSpace: CGFloat = vm.showSuggestion ? suggestionHeight + 8 : 0
        if keyboard.height > 0 {
            return keyboard.height - safeBottom + inputRowHeight + suggestionSpace + extraBottomPadding
        } else {
            return safeBottom + inputRowHeight + suggestionSpace + extraBottomPadding
        }
    }
}

final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    @Published var animationDuration: Double = 0.25

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(willShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(willHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func willShow(_ note: Notification) {
        if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            animationDuration = duration
            withAnimation(.easeOut(duration: duration)) {
                height = frame.height
            }
        }
    }

    @objc private func willHide(_ note: Notification) {
        if let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
            withAnimation(.easeOut(duration: duration)) {
                height = 0
            }
        }
    }
}

#Preview("ChatView Preview") {
    ChatView(isLocked: .constant(false), onLockAction: {})
        .statusBarHidden(true)
}
