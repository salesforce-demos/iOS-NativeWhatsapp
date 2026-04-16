//
//  ChatsListViewModel.swift
//  NotificationLiquidGlass
//

import SwiftUI

class ChatsListViewModel: ObservableObject {
    @Published var chatScenarios: [ChatScenario] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil

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
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Texto del último mensaje para mostrar en la fila
    func lastMessagePreview(for config: ChatConfig) -> String {
        let messages = config.messagesFilteredByDate?.flatMap { $0.messages ?? [] } ?? []
        return messages.last?.text ?? ""
    }

    /// Hora del último mensaje
    func lastMessageTime(for config: ChatConfig) -> String {
        let messages = config.messagesFilteredByDate?.flatMap { $0.messages ?? [] } ?? []
        return messages.last?.sendTime ?? ""
    }
}
