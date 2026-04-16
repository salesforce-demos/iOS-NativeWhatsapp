//
//  ChatViewModel.swift
//  NotificationLiquidGlass
//
//  Created by Andres Marin on 13/02/26.
//

import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    // --- ESTADO UI ---
    @Published var messages: [UIMessage] = []
    @Published var isTyping: Bool = false
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    
    // --- SUGERENCIAS INTELIGENTES ---
    @Published var currentSuggestion: String? = nil
    @Published var showSuggestion: Bool = false
    
    // --- DATOS HEADER ---
    @Published var chatTitle: String = "Cargando..."
    @Published var contactName: String = "Contacto"
    @Published var contactStatus: String = "conectando..."
    // Ahora usamos URL opcional en vez de string
    @Published var contactAvatarURL: URL? = nil
    
    // --- STATUSBAR CONFIG ---
    @Published var statusBarChatView: StatusBarSettings? = nil
    
    // --- LÓGICA INTERNA ---
    private var script: [JSONMessage] = []
    private var currentStepIndex = 0
    private var transcriptSpeed: Double = 0.5
    private var isLoadingData = false
    private var waitingForUserSelection = false // Nueva bandera para pausar el flujo
    
    // URL Base para reconstruir las imágenes relativas (ahora dinámica)
    private var baseResourceURL: String {
        let fullURL = NetworkService.shared.baseURL
        
        if let url = URL(string: fullURL) {
            let scheme = url.scheme ?? "https"
            let host = url.host ?? ""
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            
            // Buscar hasta dónde incluir el path (antes de "resource")
            var basePath = ""
            for component in pathComponents {
                if component.lowercased() == "resource" || component.contains(".json") {
                    break
                }
                basePath += "/\(component)"
            }
            
            return "\(scheme)://\(host)\(basePath)"
        }
        
        // Fallback: retornar la URL completa
        return fullURL
    }
    
    init() { }

    /// Inicializa el ViewModel con un ChatConfig ya cargado (desde la lista de chats)
    init(config: ChatConfig) {
        setupChat(with: config)
        isLoading = false
    }

    func loadData() {
        // Evitar cargas concurrentes o duplicadas
        if isLoadingData { return }
        isLoadingData = true

        // Placeholders iniciales
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.chatTitle = "Cargando..."
            self.contactName = self.contactName.isEmpty ? "Contacto" : self.contactName
            self.contactStatus = "conectando..."
            self.contactAvatarURL = nil
        }

        NetworkService.shared.fetchChatConfig { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isLoadingData = false
                self.isLoading = false
                switch result {
                case .success(let root):
                    if let config = root.einsteinChat?.chatConfig {
                        self.setupChat(with: config)
                    } else {
                        self.errorMessage = "No se encontró configuración de chat"
                        self.contactStatus = "Sin conexión"
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.contactStatus = "Sin conexión"
                }
            }
        }
    }
    
    private func setupChat(with config: ChatConfig) {
        self.chatTitle = config.configName
        self.contactName = config.contactName.isEmpty ? "Contacto" : config.contactName
        self.contactStatus = "en línea"
        
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
    
    // MARK: - Sugerencias Inteligentes
    func updateSuggestion(for inputText: String) {
        // Verificar si el siguiente mensaje requiere trigger manual
        guard currentStepIndex < script.count else {
            hideSuggestion()
            return
        }
        
        let nextMsg = script[currentStepIndex]
        
        // SOLO mostrar sugerencia si es un mensaje del usuario que NO se envía automáticamente
        guard nextMsg.isCurrentUser && !nextMsg.shouldAutoSend else {
            hideSuggestion()
            return
        }
        
        // Resetear si el texto está vacío
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
    
    /// Aplica la sugerencia y ejecuta el trigger automático
    func applySuggestionAndSend() {
        // Ocultar la sugerencia primero
        hideSuggestion()
        
        // Ejecutar el manual trigger para procesar el mensaje
        manualTrigger()
    }
    
    func handleOptionSelected(_ option: MessageOption) {
        print("Usuario seleccionó: \(option.displayText)")
        print("Estado actual: currentStepIndex=\(currentStepIndex), totalMessages=\(messages.count)")
        
        // Buscar el último mensaje con opciones y remover las opciones
        if let lastMessageWithOptionsIndex = messages.lastIndex(where: { $0.options != nil && !($0.options?.isEmpty ?? true) }) {
            let originalMessage = messages[lastMessageWithOptionsIndex]
            // Crear un nuevo mensaje sin opciones
            let messageWithoutOptions = UIMessage(
                text: originalMessage.text,
                isCurrentUser: originalMessage.isCurrentUser,
                timestamp: originalMessage.timestamp,
                imageURL: originalMessage.imageURL,
                options: nil // Removemos las opciones
            )
            
            withAnimation {
                messages[lastMessageWithOptionsIndex] = messageWithoutOptions
            }
        }
        
        // Agregar la opción seleccionada como mensaje del usuario
        addMessage(option.displayText, isCurrentUser: true)
        
        // Saltar el siguiente mensaje del script si es del usuario
        if currentStepIndex < script.count {
            let nextMsg = script[currentStepIndex]
            if nextMsg.isCurrentUser {
                print("Saltando mensaje \(currentStepIndex + 1) del script (ya fue agregado por selección de opción)")
                currentStepIndex += 1
            }
        }
        
        print("Esperando 0.8s antes de reanudar flujo...")
        
        // Esperar un momento antes de continuar con el siguiente mensaje automático
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            
            print("Reanudando flujo del chat después del delay...")
            
            // Ahora sí, reanudar el flujo
            self.waitingForUserSelection = false
            
            // Verificar que tenemos mensajes pendientes
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
        
        // Si estamos esperando que el usuario seleccione una opción, no continuar
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
            addMessage(step.contentText, isCurrentUser: true, imageURL: step.imageURL, options: step.options)
            checkNextStep()
        } else {
            triggerFakeResponse(text: step.contentText, imageURL: step.imageURL, options: step.options)
        }
    }
    
    private func addMessage(_ text: String, isCurrentUser: Bool, imageURL: String? = nil, options: [MessageOption]? = nil) {
        let newMessage = UIMessage(
            text: text,
            isCurrentUser: isCurrentUser,
            timestamp: Date(),
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
    
    private func triggerFakeResponse(text: String, imageURL: String? = nil, options: [MessageOption]? = nil) {
        withAnimation { self.isTyping = true }
        self.contactStatus = "escribiendo..."

        let typingDuration = min(Double(text.count) * 0.05, 2.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) { [weak self] in
            guard let self = self else { return }
            
            self.addMessage(text, isCurrentUser: false, imageURL: imageURL, options: options)
            withAnimation { self.isTyping = false }
            self.contactStatus = "en línea"

            // Si el mensaje tiene opciones, pausar el flujo
            if let options = options, !options.isEmpty {
                self.waitingForUserSelection = true
                return
            }

            // Pequeño delay antes del siguiente paso
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

        chatTitle = "Cargando..."
        contactName = "Contacto"
        contactStatus = "conectando..."
        contactAvatarURL = nil

        script = []
        currentStepIndex = 0
        transcriptSpeed = 0.5
        waitingForUserSelection = false // Resetear la bandera
        
        // Resetear sugerencias
        currentSuggestion = nil
        showSuggestion = false
    }

    // MARK: - New Method: sendTextMessage
    func sendTextMessage(_ text: String) {
        // Asegurarse de que el texto no esté vacío antes de enviarlo
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Añadir el mensaje del usuario al chat
        addMessage(text, isCurrentUser: true)

        // Ocultar cualquier sugerencia activa, ya que el usuario ha ingresado texto manualmente
        hideSuggestion()

        // Después de que el usuario envía un mensaje, podemos querer que el bot
        // automáticamente verifique el siguiente paso en el script si es un mensaje de envío automático.
        // Esto permite que el bot reaccione a la entrada del usuario.
        // Se añade un pequeño retardo para una interacción más natural.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkNextStep()
        }
    }
}

