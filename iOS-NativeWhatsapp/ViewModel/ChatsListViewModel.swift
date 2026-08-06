import SwiftUI

class ChatsListViewModel: ObservableObject {
    @Published var chatScenarios: [ChatScenario] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published private(set) var readChats: Set<String> = []

    func loadChats() {
        isLoading = true
        errorMessage = nil

        NetworkService.shared.fetchAllChats { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let scenarios):
                    self.chatScenarios = scenarios
                    WAImageCache.shared.prefetch(
                        scenarios.flatMap { [$0.chatConfig.agentImageURL, $0.chatConfig.contactImageURL] }
                    )
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func lastMessagePreview(for config: ChatConfig) -> String {
        if let text = config.lastMessage, !text.isEmpty { return text }
        let messages = config.messagesFilteredByDate?.flatMap { $0.messages ?? [] } ?? []
        return messages.last?.text ?? ""
    }

    func lastMessageTime(for config: ChatConfig) -> String {
        if let time = config.lastMessageTime, !time.isEmpty { return time }
        let messages = config.messagesFilteredByDate?.flatMap { $0.messages ?? [] } ?? []
        return messages.last?.sendTime ?? ""
    }

    func unreadCount(for config: ChatConfig) -> Int {
        if readChats.contains(key(for: config)) { return 0 }
        return max(0, config.unreadCount ?? 0)
    }

    func markAsRead(_ config: ChatConfig) {
        readChats.insert(key(for: config))
    }

    func resetReadState() {
        readChats.removeAll()
    }

    private func key(for config: ChatConfig) -> String {
        config.configName + "|" + config.contactName
    }

    var unreadChats: Int {
        chatScenarios.filter { unreadCount(for: $0.chatConfig) > 0 }.count
    }

    var groupChats: Int {
        chatScenarios.filter { $0.chatConfig.isGroup == true }.count
    }
}
