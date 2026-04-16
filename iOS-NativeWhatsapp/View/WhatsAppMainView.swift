//
//  WhatsAppMainView.swift
//  NotificationLiquidGlass
//

import SwiftUI

// MARK: - Tab identifiers
enum WATab: Hashable {
    case updates, calls, communities, chats, you
}

// MARK: - Main entry with TabView (iOS 26 Liquid Glass tab bar automático)
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
    }
}

// MARK: - Chats tab
struct WAChatsView: View {
    @Binding var isLocked: Bool
    var onLockAction: () -> Void

    @StateObject private var listVM = ChatsListViewModel()
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var tabBarHidden = false
    @State private var selectedConfig: ChatConfig? = nil

    private let filters = ["All", "Unread", "Favorites", "Groups"]
    private let waGreen = Color(red: 0.0, green: 0.659, blue: 0.518)
    private let waGreenDark = Color(red: 0.067, green: 0.475, blue: 0.424)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

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
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 12)

                            filterBar
                                .padding(.bottom, 12)

                            Divider().opacity(0.35)

                            ForEach(Array(listVM.chatScenarios.enumerated()), id: \.offset) { index, scenario in
                                chatRow(for: scenario.chatConfig)
                                    .onTapGesture {
                                        tabBarHidden = true
                                        selectedConfig = scenario.chatConfig
                                    }

                                Divider().padding(.leading, 76).opacity(0.35)
                            }
                        }
                    }
                }

                // Navegación al chat seleccionado
                Color.clear
                    .navigationDestination(isPresented: Binding(
                        get: { selectedConfig != nil },
                        set: { if !$0 { selectedConfig = nil } }
                    )) {
                        if let config = selectedConfig {
                            ChatView(
                                isLocked: $isLocked,
                                config: config,
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(tabBarHidden ? .hidden : .visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { onLockAction() }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let first = listVM.chatScenarios.first {
                            tabBarHidden = true
                            selectedConfig = first.chatConfig
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(waGreen))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task { listVM.loadChats() }
    }

    // MARK: Search bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            TextField("Ask Meta AI or Search", text: $searchText)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Filter chips
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ label: String) -> some View {
        let isSelected = selectedFilter == label
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedFilter = label
            }
        }) {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? waGreenDark : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? waGreen.opacity(0.18) : Color.clear)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? waGreen.opacity(0.5) : Color(.systemGray4),
                                    lineWidth: 1.2
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Chat row dinámico
    private func chatRow(for config: ChatConfig) -> some View {
        let lastMsg = listVM.lastMessagePreview(for: config)
        let lastTime = listVM.lastMessageTime(for: config)
        let initial = String(config.contactName.prefix(1).uppercased())

        return HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(red: 0.067, green: 0.475, blue: 0.424))
                    .frame(width: 52, height: 52)
                if let urlStr = config.agentImageURL ?? config.contactImageURL,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(Circle())
                        default:
                            Text(initial)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    Text(initial)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(config.contactName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(lastTime)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text(lastMsg)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Placeholder para tabs sin contenido
struct WAPlaceholderView: View {
    let title: String
    var body: some View {
        NavigationStack {
            Color(.systemBackground)
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

// MARK: - Preview
#Preview("WhatsAppMainView") {
    WhatsAppMainView(isLocked: .constant(false), onLockAction: {})
}
