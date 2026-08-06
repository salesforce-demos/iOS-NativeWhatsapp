import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [UIMessage] = []
    @Published var isTyping: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil

    @Published var currentSuggestion: String? = nil
    @Published var showSuggestion: Bool = false

    @Published var chatTitle: String = "Loading…"
    @Published var contactName: String = "Contact"
    @Published var contactStatus: String = "connecting…"
    @Published var contactAvatarURL: URL? = nil

    @Published var statusBarChatView: StatusBarSettings? = nil

    @Published var chatURL: URL? = nil
    @Published var isVerified: Bool = false
    @Published var businessName: String? = nil
    @Published var isLogoAvatar: Bool = false

    private var script: [JSONMessage] = []
    private var currentStepIndex = 0
    private var transcriptSpeed: Double = 0.5
    private var isLoadingData = false
    private var waitingForUserSelection = false

    private var baseResourceURL: String {
        let fullURL = NetworkService.shared.baseURL

        if let url = URL(string: fullURL) {
            let scheme = url.scheme ?? "https"
            let host = url.host ?? ""
            let pathComponents = url.pathComponents.filter { $0 != "/" }

            var basePath = ""
            for component in pathComponents {
                if component.lowercased() == "resource" || component.contains(".json") {
                    break
                }
                basePath += "/\(component)"
            }

            return "\(scheme)://\(host)\(basePath)"
        }

        return fullURL
    }

    init() { }

    init(config: ChatConfig) {
        setupChat(with: config)
        isLoading = false
    }

    func loadData() {
        if isLoadingData { return }
        isLoadingData = true

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.chatTitle = "Loading…"
            self.contactName = self.contactName.isEmpty ? "Contact" : self.contactName
            self.contactStatus = "connecting…"
            self.contactAvatarURL = nil
        }

        NetworkService.shared.fetchChatConfig { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoadingData = false
                self.isLoading = false
                switch result {
                case .success(let root):
                    if let config = root.einsteinChat?.chatConfig ?? root.allChats.first?.chatConfig {
                        self.setupChat(with: config)
                    } else {
                        self.errorMessage = "Chat configuration not found"
                        self.contactStatus = "Offline"
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.contactStatus = "Offline"
                }
            }
        }
    }

    private func setupChat(with config: ChatConfig) {
        self.chatTitle = config.configName
        self.contactName = config.contactName.isEmpty ? "Contact" : config.contactName
        self.contactStatus = config.contactStatus ?? "online"

        self.isVerified = config.isVerified ?? false
        self.businessName = config.businessName
        self.isLogoAvatar = (config.avatarStyle ?? "photo").lowercased() == "logo"

        if let raw = config.chatURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            self.chatURL = URL(string: raw)
        } else {
            self.chatURL = nil
        }

        if let rawImage = config.agentImageURL ?? config.botImageURL {
            self.contactAvatarURL = resolveImageURL(rawPath: rawImage)
        }

        if let statusBarConfig = config.statusBar {
            self.statusBarChatView = statusBarConfig.chatview
        }

        let speedMs = Double(config.transcriptSpeed ?? 500)
        self.transcriptSpeed = speedMs / 1000.0

        self.script = config.messagesFilteredByDate?
            .flatMap { $0.messages ?? [] } ?? []

        self.currentStepIndex = 0
        self.messages = []

        checkNextStep()
    }

    private func resolveImageURL(rawPath: String) -> URL? {
        if rawPath.hasPrefix("http") {
            return URL(string: rawPath)
        }

        var cleanPath = rawPath
        if cleanPath.hasPrefix("..") {
            cleanPath = String(cleanPath.dropFirst(2))
        }

        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }

        let fullString = baseResourceURL + cleanPath
        return URL(string: fullString)
    }

    func manualTrigger() {
        if !isTyping && currentStepIndex < script.count {
            let nextMsg = script[currentStepIndex]
            if !nextMsg.shouldAutoSend {
                processNextMessage()
            }
        }
    }

    func updateSuggestion(for inputText: String) {
        guard currentStepIndex < script.count else {
            hideSuggestion()
            return
        }

        let nextMsg = script[currentStepIndex]

        guard nextMsg.isCurrentUser && !nextMsg.shouldAutoSend else {
            hideSuggestion()
            return
        }

        guard !inputText.isEmpty else {
            hideSuggestion()
            return
        }

        let nextMessage = nextMsg.contentText
        guard !nextMessage.isEmpty else {
            hideSuggestion()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentSuggestion = nextMessage
            showSuggestion = true
        }
    }

    private func hideSuggestion() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showSuggestion = false
            currentSuggestion = nil
        }
    }

    func applySuggestionAndSend() {
        hideSuggestion()

        manualTrigger()
    }

    func handleOptionSelected(_ option: MessageOption) {
        print("Usuario seleccionó: \(option.displayText)")
        print("Estado actual: currentStepIndex=\(currentStepIndex), totalMessages=\(messages.count)")

        if let lastMessageWithOptionsIndex = messages.lastIndex(where: { $0.options != nil && !($0.options?.isEmpty ?? true) }) {
            let originalMessage = messages[lastMessageWithOptionsIndex]
            let messageWithoutOptions = UIMessage(
                text: originalMessage.text,
                isCurrentUser: originalMessage.isCurrentUser,
                timestamp: originalMessage.timestamp,
                imageURL: originalMessage.imageURL,
                options: nil
            )

            withAnimation {
                messages[lastMessageWithOptionsIndex] = messageWithoutOptions
            }
        }

        addMessage(option.displayText, isCurrentUser: true)

        if currentStepIndex < script.count {
            let nextMsg = script[currentStepIndex]
            if nextMsg.isCurrentUser {
                print("Saltando mensaje \(currentStepIndex + 1) del script (ya fue agregado por selección de opción)")
                currentStepIndex += 1
            }
        }

        print("Esperando 0.8s antes de reanudar flujo...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }

            print("Reanudando flujo del chat después del delay...")

            self.waitingForUserSelection = false

            if self.currentStepIndex < self.script.count {
                print("Continuando con mensaje \(self.currentStepIndex + 1)/\(self.script.count)")
                self.checkNextStep()
            } else {
                print("No hay más mensajes para procesar")
            }
        }
    }

    private func checkNextStep() {
        guard currentStepIndex < script.count else {
            print("Chat completado. No hay más mensajes.")
            return
        }

        if waitingForUserSelection {
            print("Esperando selección del usuario...")
            return
        }

        let nextMsg = script[currentStepIndex]
        print("Verificando paso \(currentStepIndex + 1)/\(script.count): sender=\(nextMsg.sender ?? "unknown"), auto=\(nextMsg.shouldAutoSend)")

        if nextMsg.shouldAutoSend {
            let delay = nextMsg.isCurrentUser ? 0.5 : 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.processNextMessage()
            }
        } else {
            print("Mensaje no automático. Esperando trigger manual.")
        }
    }

    private func processNextMessage() {
        guard currentStepIndex < script.count else {
            return
        }

        let step = script[currentStepIndex]
        currentStepIndex += 1

        if step.isCurrentUser {
            addMessage(step.contentText, isCurrentUser: true, imageURL: step.imageURL, options: step.options, sendTime: step.sendTime)
            checkNextStep()
        } else {
            triggerFakeResponse(text: step.contentText, imageURL: step.imageURL, options: step.options, sendTime: step.sendTime)
        }
    }

    private static func timestamp(from sendTime: String?) -> Date {
        guard let raw = sendTime?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return Date() }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["h:mm a", "h:mma", "HH:mm", "H:mm"] {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: raw) {
                let calendar = Calendar.current
                let hm = calendar.dateComponents([.hour, .minute], from: parsed)
                if let today = calendar.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: Date()) {
                    return today
                }
            }
        }
        return Date()
    }

    private func addMessage(_ text: String, isCurrentUser: Bool, imageURL: String? = nil, options: [MessageOption]? = nil, sendTime: String? = nil) {
        let newMessage = UIMessage(
            text: text,
            isCurrentUser: isCurrentUser,
            timestamp: Self.timestamp(from: sendTime),
            imageURL: imageURL,
            options: options
        )

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            self.messages.append(newMessage)
        }

        if !isCurrentUser {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }

    private func triggerFakeResponse(text: String, imageURL: String? = nil, options: [MessageOption]? = nil, sendTime: String? = nil) {
        withAnimation { self.isTyping = true }
        self.contactStatus = "typing…"

        let typingDuration = min(Double(text.count) * 0.05, 2.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) { [weak self] in
            guard let self = self else { return }

            self.addMessage(text, isCurrentUser: false, imageURL: imageURL, options: options, sendTime: sendTime)
            withAnimation { self.isTyping = false }
            self.contactStatus = "online"

            if let options = options, !options.isEmpty {
                self.waitingForUserSelection = true
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + self.transcriptSpeed) { [weak self] in
                self?.checkNextStep()
            }
        }
    }

    func resetChat() {
        messages = []
        isTyping = false
        isLoading = false
        errorMessage = nil

        chatTitle = "Loading…"
        contactName = "Contact"
        contactStatus = "connecting…"
        contactAvatarURL = nil
        chatURL = nil
        isVerified = false
        isLogoAvatar = false
        businessName = nil

        script = []
        currentStepIndex = 0
        transcriptSpeed = 0.5
        waitingForUserSelection = false

        currentSuggestion = nil
        showSuggestion = false
    }

    func sendTextMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        addMessage(text, isCurrentUser: true)

        hideSuggestion()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkNextStep()
        }
    }
}
