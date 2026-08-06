import SwiftUI

struct URLConfigurationView: View {
    @Binding var chatServiceURL: String
    @Binding var isConfigured: Bool

    @State private var inputURL: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.98), Color(white: 0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                topBar

                Spacer().frame(height: 120)

                logoSection

                searchBar

                Spacer()

                bottomBars
            }
        }
        .onAppear {
            if !chatServiceURL.isEmpty {
                inputURL = chatServiceURL
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: {}) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: {}) {
                    Text("ALL")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }

                Button(action: {}) {
                    Text("IMAGES")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }

                Button(action: {}) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }

                Button(action: {}) {
                    Text("SignIn")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.blue))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var logoSection: some View {
        Image("Google")
            .resizable()
            .scaledToFit()
            .frame(height: 90)
            .padding(.bottom, 30)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                performSearch()
            }) {
                ZStack {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                            .tint(.gray)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .disabled(isSearching)

            TextField("", text: $inputURL, prompt: Text("Search").foregroundColor(.gray.opacity(0.6)))
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($isTextFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }

            if !inputURL.isEmpty {
                Button(action: {
                    inputURL = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }

            Button(action: {}) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }

            Button(action: {}) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }

    private var bottomBars: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button(action: {}) {
                    Text("Dark theme: off")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Button(action: {}) {
                    Text("Settings")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Button(action: {}) {
                    Text("Privacy")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Button(action: {}) {
                    Text("Terms")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 16) {
                Button(action: {}) {
                    Text("Advertising")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Button(action: {}) {
                    Text("Business")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Button(action: {}) {
                    Text("About")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.bottom, 8)
    }

    private func useLocalJSON() {
        inputURL = ""
        load(urlToSave: "")
    }

    private func performSearch() {
        let trimmedURL = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedURL.isEmpty {
            useLocalJSON()
            return
        }

        var urlToSave = trimmedURL
        if !urlToSave.lowercased().hasPrefix("http://") && !urlToSave.lowercased().hasPrefix("https://") {
            urlToSave = "https://" + urlToSave
        }
        load(urlToSave: urlToSave)
    }

    private func load(urlToSave: String) {
        isSearching = true
        isTextFieldFocused = false

        chatServiceURL = urlToSave
        UserDefaults.standard.set(urlToSave, forKey: "chatServiceURL")
        NetworkService.shared.baseURL = urlToSave

        NetworkService.shared.fetchAllChats { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let scenarios):
                    WAImageCache.shared.preload(from: scenarios) {
                        enter()
                    }
                case .failure:
                    enter()
                }
            }
        }
    }

    private func enter() {
        isSearching = false
        withAnimation(.easeInOut(duration: 0.3)) {
            isConfigured = true
        }
    }
}

#Preview {
    URLConfigurationView(
        chatServiceURL: .constant(""),
        isConfigured: .constant(false)
    )
}
