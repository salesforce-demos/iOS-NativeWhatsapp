import SwiftUI

enum WATab: Hashable {
    case updates, calls, communities, chats, you
}

struct WhatsAppMainView: View {
    @Binding var isLocked: Bool
    var onLockAction: () -> Void

    @State private var selectedTab: WATab = .chats

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Updates", image: selectedTab == .updates ? "status-fill" : "status", value: WATab.updates) {
                WAPlaceholderView(title: "Updates")
            }

            Tab("Calls", image: selectedTab == .calls ? "calls-fill" : "calls", value: WATab.calls) {
                WAPlaceholderView(title: "Calls")
            }

            Tab("Communities", image: selectedTab == .communities ? "communities-fill" : "communities", value: WATab.communities) {
                WAPlaceholderView(title: "Communities")
            }

            Tab("Chats", image: selectedTab == .chats ? "chats-fill" : "chats", value: WATab.chats) {
                WAChatsView(
                    isLocked: $isLocked,
                    onLockAction: onLockAction
                )
            }

            Tab(value: WATab.you) {
                WAPlaceholderView(title: "You")
            } label: {
                Label("You", systemImage: selectedTab == .you ? "person.crop.circle.fill" : "person.crop.circle")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.black)
    }
}

private struct WAFilter: Identifiable {
    let id = UUID()
    let title: String
    var count: Int = 0
}

struct WAChatsView: View {
    @Binding var isLocked: Bool
    var onLockAction: () -> Void

    @StateObject private var listVM = ChatsListViewModel()
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var tabBarHidden = false
    @State private var selectedConfig: ChatConfig? = nil

    private var filters: [WAFilter] {
        [
            WAFilter(title: "All"),
            WAFilter(title: "Unread", count: listVM.unreadChats),
            WAFilter(title: "Favorites"),
            WAFilter(title: "Groups", count: listVM.groupChats)
        ]
    }

    private var statusBar: StatusBarSettings? {
        listVM.chatScenarios.first?.chatConfig.statusBar?.chatview
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if listVM.isLoading {
                    ProgressView()
                } else if let error = listVM.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle).foregroundStyle(.orange)
                        Text(error).multilineTextAlignment(.center).padding()
                        Button("Retry") { listVM.loadChats() }
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            searchBar
                                .padding(.horizontal, 20)
                                .padding(.top, 1)
                                .padding(.bottom, 24)

                            filterBar
                                .padding(.bottom, 12)

                            archivedRow

                            rowDivider

                            ForEach(Array(listVM.chatScenarios.enumerated()), id: \.offset) { index, scenario in
                                chatRow(for: scenario.chatConfig)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        tabBarHidden = true
                                        selectedConfig = scenario.chatConfig
                                    }

                                rowDivider
                            }
                        }
                    }
                }

                Color.clear
                    .navigationDestination(isPresented: Binding(
                        get: { selectedConfig != nil },
                        set: { if !$0 { selectedConfig = nil } }
                    )) {
                        if let config = selectedConfig {
                            ChatView(
                                isLocked: $isLocked,
                                config: config,
                                backBadge: listVM.unreadChats > 0 ? "\(listVM.unreadChats)" : nil,
                                onLockAction: {
                                    tabBarHidden = false
                                    selectedConfig = nil
                                }
                            )
                            .toolbar(.hidden, for: .tabBar)
                            .onDisappear { tabBarHidden = false }
                        }
                    }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(tabBarHidden ? .hidden : .visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    WAGlassCircleButton(action: { onLockAction() }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17))
                            .foregroundStyle(.black)
                    }
                    .padding(.leading, -4)
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        WAGlassCircleButton(action: {}) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(.black)
                        }

                        WAGlassCircleButton(fill: WA.green, action: {
                            if let first = listVM.chatScenarios.first {
                                tabBarHidden = true
                                selectedConfig = first.chatConfig
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.trailing, -4)
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .overlay(alignment: .top) {
            if selectedConfig == nil {
                WAStatusBarSlot(
                    carrier: statusBar?.carrier ?? "Carrier",
                    signalBars: statusBar?.signalBars ?? 4,
                    wifiStrength: statusBar?.wifiStrength ?? 3,
                    showWifi: statusBar?.showWifi ?? true,
                    levelBattery: statusBar?.levelBattery ?? 0.3,
                    isCharging: statusBar?.isCharging ?? false
                )
                .background(Color.white)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
            }
        }
        .task { listVM.loadChats() }
        .onChange(of: listVM.chatScenarios.count) { _, _ in
            for scenario in listVM.chatScenarios {
                if let raw = scenario.chatConfig.chatURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !raw.isEmpty, let url = URL(string: raw) {
                    ChatWebCache.shared.preload(url)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17))
                .foregroundStyle(WA.secondary)

            TextField(
                "",
                text: $searchText,
                prompt: Text("Ask Meta AI or Search")
                    .font(.system(size: 17))
                    .foregroundColor(WA.secondary)
            )
            .font(.system(size: 17))
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(height: 44)
        .background(Capsule().fill(WA.searchFill))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    filterChip(filter)
                }
                addFilterChip
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
    }

    private func filterChip(_ filter: WAFilter) -> some View {
        let isSelected = selectedFilter == filter.title
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedFilter = filter.title
            }
        }) {
            HStack(spacing: 6) {
                Text(filter.title)
                    .font(.system(size: 15))
                if filter.count > 0 {
                    Text("\(filter.count)")
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(isSelected ? WA.chipText : WA.secondary)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(isSelected ? WA.chipFill : Color.clear)
                    .overlay(
                        Capsule().strokeBorder(isSelected ? WA.chipStroke : WA.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var addFilterChip: some View {
        Button(action: {}) {
            Image(systemName: "plus")
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .frame(width: 35, height: 32)
                .background(
                    Capsule().strokeBorder(WA.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var archivedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 19))
                .foregroundStyle(WA.secondary)
                .frame(width: WA.rowAvatarSize)

            Text("Archived")
                .font(.system(size: 17))
                .foregroundStyle(.black)

            Spacer()
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(WA.divider)
            .frame(height: 1)
            .padding(.leading, WA.rowTextLeading)
            .padding(.trailing, 16)
    }

    private func chatRow(for config: ChatConfig) -> some View {
        let lastMsg = listVM.lastMessagePreview(for: config)
        let lastTime = listVM.lastMessageTime(for: config)
        let unread = listVM.unreadCount(for: config)

        return HStack(alignment: .top, spacing: 12) {
            AvatarView(
                url: URL(string: config.agentImageURL ?? config.contactImageURL ?? ""),
                text: config.contactName,
                size: WA.rowAvatarSize,
                isLogo: (config.avatarStyle ?? "photo").lowercased() == "logo"
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(config.contactName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    if config.isVerified == true {
                        WAVerifiedBadge(size: 15)
                    }

                    Spacer(minLength: 4)

                    if !lastTime.isEmpty {
                        Text(lastTime)
                            .font(.system(size: 15))
                            .foregroundStyle(WA.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Text(lastMsg)
                        .font(.system(size: 16))
                        .foregroundStyle(WA.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)

                    if unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(WA.green))
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
    }
}

struct WAPlaceholderView: View {
    let title: String
    var body: some View {
        NavigationStack {
            Color.white
                .ignoresSafeArea()
                .overlay(
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                )
                .navigationTitle(title)
        }
    }
}

#Preview("WhatsAppMainView") {
    WhatsAppMainView(isLocked: .constant(false), onLockAction: {})
}
