import SwiftUI

struct LockScreenNotification: Identifiable {
    let id = UUID()
    let appName: String
    let iconName: String
    let iconColor: Color
    let title: String
    let message: String
    let timeAgo: String
}

class LockScreenViewModel: ObservableObject {
    @Published var notifications: [LockScreenNotification] = []
    @Published var statusBarLockScreen: StatusBarSettings? = nil

    private var notificationConfigs: [NotificationConfig] = []
    private var isDataLoaded = false

    func loadData() {
        guard !isDataLoaded else { return }

        NetworkService.shared.fetchChatConfig { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let root):
                    if let config = root.einsteinChat?.chatConfig {
                        self.statusBarLockScreen = config.statusBar?.lockscreen

                        self.notificationConfigs = config.notifications ?? []

                        self.isDataLoaded = true
                    }
                case .failure(let error):
                    print("Error loading lock screen config: \(error.localizedDescription)")
                }
            }
        }
    }

    func addNotification() {
        guard !notificationConfigs.isEmpty else {
            print("No hay notificaciones configuradas en el JSON")
            return
        }

        let config = notificationConfigs.randomElement()!

        let newNotif = LockScreenNotification(
            appName: config.appName ?? "App",
            iconName: config.iconName ?? "app.fill",
            iconColor: parseColor(config.iconColor ?? "#007AFF"),
            title: config.title ?? "Notification",
            message: config.message ?? "",
            timeAgo: config.timeAgo ?? "ahora"
        )

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            notifications.insert(newNotif, at: 0)
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func parseColor(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}
