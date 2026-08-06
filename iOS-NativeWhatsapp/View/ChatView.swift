import SwiftUI

struct ChatView: View {
    @Binding var isLocked: Bool
    var onLockAction: () -> Void

    @StateObject private var vm: ChatViewModel
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject private var web = ChatWebController()
    @State private var inputText = ""
    @State private var currentTime = Date()
    @State private var conversationStarted = false
    @FocusState private var isInputFocused: Bool

    private let hasInjectedConfig: Bool
    var backBadge: String? = nil

    init(isLocked: Binding<Bool>, config: ChatConfig? = nil, backBadge: String? = nil, onLockAction: @escaping () -> Void) {
        self._isLocked = isLocked
        self.onLockAction = onLockAction
        self.backBadge = backBadge
        if let config = config {
            self._vm = StateObject(wrappedValue: ChatViewModel(config: config))
            self.hasInjectedConfig = true
        } else {
            self._vm = StateObject(wrappedValue: ChatViewModel())
            self.hasInjectedConfig = false
        }
    }

    private let inputRowHeight: CGFloat = WA.inputRowHeight
    private let suggestionHeight: CGFloat = 100
    private let extraBottomPadding: CGFloat = 16
    private let headerHeight: CGFloat = WA.headerHeight

    var body: some View {
        ZStack(alignment: .top) {
            chatContent

            WAStatusBarSlot(
                carrier: vm.statusBarChatView?.carrier ?? "Carrier",
                signalBars: vm.statusBarChatView?.signalBars ?? 4,
                wifiStrength: vm.statusBarChatView?.wifiStrength ?? 3,
                showWifi: vm.statusBarChatView?.showWifi ?? true,
                levelBattery: vm.statusBarChatView?.levelBattery ?? 0.3,
                isCharging: vm.statusBarChatView?.isCharging ?? false
            )
            .background(WA.chrome)
        }
        .ignoresSafeArea(edges: .top)
    }
}

private extension ChatView {
    var chatContent: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                WAChatWallpaper(dimmed: vm.chatURL == nil)

                if let error = vm.errorMessage {
                    errorView(error)
                } else if let url = vm.chatURL {
                    webChat(url: url, geo: geo)
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
                if let url = vm.chatURL { ChatWebCache.shared.refresh(url) }
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
        ChatHeaderView(
            title: vm.contactName,
            subtitle: vm.contactStatus,
            avatarURL: vm.contactAvatarURL,
            backBadge: backBadge,
            isVerified: vm.isVerified,
            isLogoAvatar: vm.isLogoAvatar,
            businessName: vm.businessName,
            onBack: {
                isInputFocused = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    onLockAction()
                }
            },
            onTitleTap: { advanceConversation() },
            onVideoCall: { UIImpactFeedbackGenerator(style: .light).impactOccurred() },
            onVoiceCall: { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        )
        .ignoresSafeArea(edges: .top)
    }

    func webChat(url: URL, geo: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            ChatWebView(url: url, controller: web)

            if let error = web.lastError {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(WA.secondary)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(WA.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { web.reload() }
                        .font(.system(size: 15, weight: .semibold))
                        .tint(WA.green)
                }
                .padding(24)
            } else if web.isLoading {
                ProgressView().tint(WA.secondary)
            }

            WADateSeparator(text: formattedDay(for: Date()))
                .padding(.top, headerHeight + 10)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, webBottomInset(safeBottom: geo.safeAreaInsets.bottom))
        .onAppear {
            web.dayLabel = formattedDay(for: Date())
            if conversationStarted {
                web.scrollToBottom()
            } else {
                web.resetToTop()
            }
        }
        .onChange(of: keyboard.height) { oldHeight, newHeight in
            if newHeight > oldHeight { web.scrollToBottom() }
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused { web.scrollToBottom() }
        }
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
            Button("Retry") { vm.loadData() }
            Spacer()
        }
    }

    func messageList(geo: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    WADateSeparator(text: formattedDay(for: vm.messages.first?.timestamp ?? Date()))
                        .padding(.top, 34)
                    WAEncryptionNotice()
                        .padding(.bottom, 8)

                    ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                        if index > 0, shouldShowDaySeparator(at: index) {
                            WADateSeparator(text: formattedDay(for: msg.timestamp))
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

            HStack(alignment: .bottom, spacing: 0) {
                plusButton
                    .padding(.leading, 5)

                textField
                    .padding(.leading, 6)

                if hasText {
                    sendButton
                        .padding(.leading, 10)
                } else {
                    cameraButton
                        .padding(.leading, 12)
                    micButton
                        .padding(.leading, 4)
                }
            }
            .padding(.trailing, 7)
            .padding(.vertical, 9)
            .animation(.easeOut(duration: 0.15), value: hasText)
        }
        .background(WA.chrome.ignoresSafeArea(edges: .bottom))
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
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 36, height: WA.inputFieldHeight)
        }
        .buttonStyle(.plain)
    }

    var textField: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField("", text: $inputText, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .focused($isInputFocused)
                .font(.system(size: 17))
                .lineLimit(1...5)
                .tint(WA.green)
                .padding(.vertical, 5)
                .padding(.leading, 14)
                .onChange(of: inputText) { _, newValue in
                    vm.updateSuggestion(for: newValue)
                }

            Button(action: {}) {
                StickerIcon(size: 15, lineWidth: 1.15, color: .black)
                    .frame(width: 42, height: WA.inputFieldHeight)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: WA.inputFieldHeight)
        .background(Color.white)
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(WA.fieldStroke, lineWidth: 0.5)
        )
    }

    var cameraButton: some View {
        Button(action: {}) {
            Image(systemName: "camera")
                .font(.system(size: 19))
                .foregroundStyle(.black)
                .frame(width: 36, height: WA.inputFieldHeight)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    var micButton: some View {
        Button(action: {}) {
            Image(systemName: "mic")
                .font(.system(size: 23))
                .foregroundStyle(.black)
                .frame(width: 36, height: WA.inputFieldHeight)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    var sendButton: some View {
        Button(action: { sendCurrentMessage() }) {
            ZStack {
                Circle().fill(WA.green).frame(width: 30, height: 30)
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: WA.inputFieldHeight)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }
}

private extension ChatView {
    var isWebChat: Bool { vm.chatURL != nil }

    func sendCurrentMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if isWebChat {
            web.sendMessage()
            web.scrollToBottom()
        } else {
            vm.sendTextMessage(text)
        }
        inputText = ""
    }

    func advanceConversation() {
        if isWebChat {
            conversationStarted = true
            web.sendMessage()
            web.scrollToBottom()
            inputText = ""
        } else {
            vm.manualTrigger()
        }
    }

    func webBottomInset(safeBottom: CGFloat) -> CGFloat {
        let suggestionSpace: CGFloat = vm.showSuggestion ? suggestionHeight + 8 : 0
        let keyboardSpace: CGFloat = keyboard.height > 0 ? keyboard.height - safeBottom : 0
        return inputRowHeight + suggestionSpace + keyboardSpace
    }

    func scrollToBottom(proxy: ScrollViewProxy, delay: Double = 0.22) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    func shouldShowDaySeparator(at index: Int) -> Bool {
        let messages = vm.messages
        guard index > 0, index < messages.count else { return index == 0 }
        return !Calendar.current.isDate(
            messages[index].timestamp,
            inSameDayAs: messages[index - 1].timestamp
        )
    }

    func formattedDay(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d"
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
