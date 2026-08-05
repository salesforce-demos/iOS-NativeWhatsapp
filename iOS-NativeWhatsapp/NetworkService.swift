import Foundation

class NetworkService {
    static let shared = NetworkService()

    var baseURL: String = "https://oktana156-dev-ed.develop.my.site.com/endpoint/resource/chatConfigs/chatConfigs.json"

    func fetchAllChats(completion: @escaping (Result<[ChatScenario], Error>) -> Void) {
        fetchChatConfig { result in
            switch result {
            case .success(let root):
                completion(.success(root.allChats))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchChatConfig(completion: @escaping (Result<RootConfig, Error>) -> Void) {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedURL.isEmpty {
            print("URL vacía, cargando JSON local...")
            loadLocalChatConfig(completion: completion)
            return
        }

        guard let url = URL(string: baseURL) else {
            let error = NSError(
                domain: "NetworkService",
                code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid URL: \(baseURL)"
                ]
            )
            print("Invalid URL: \(baseURL)")
            completion(.failure(error))
            return
        }

        print("Fetching chat config from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    let statusError = NSError(
                        domain: "NetworkService",
                        code: httpResponse.statusCode,
                        userInfo: [
                            NSLocalizedDescriptionKey: "HTTP error \(httpResponse.statusCode). Check that the URL is correct."
                        ]
                    )
                    completion(.failure(statusError))
                    return
                }
            }

            guard let data = data else {
                print("No data received")
                let noDataError = NSError(
                    domain: "NetworkService",
                    code: 404,
                    userInfo: [
                        NSLocalizedDescriptionKey: "No data received from the server. URL: \(url.absoluteString)"
                    ]
                )
                completion(.failure(noDataError))
                return
            }

            print("Data received: \(data.count) bytes")

            if let jsonString = String(data: data, encoding: .utf8) {
                let preview = String(jsonString.prefix(500))
                print("JSON Preview: \(preview)")
            }

            do {
                let decodedData = try JSONDecoder().decode(RootConfig.self, from: data)
                print("JSON decoded successfully")
                completion(.success(decodedData))
            } catch {
                print("JSON decode error: \(error)")

                let decodeError = NSError(
                    domain: "NetworkService",
                    code: 500,
                    userInfo: [
                        NSLocalizedDescriptionKey: "JSON decoding error: \(error.localizedDescription)"
                    ]
                )
                completion(.failure(decodeError))
            }
        }.resume()
    }

    private func loadLocalChatConfig(completion: @escaping (Result<RootConfig, Error>) -> Void) {
        guard let fileURL = Bundle.main.url(forResource: "chatConfigs", withExtension: "json") else {
            let error = NSError(
                domain: "NetworkService",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey: "Local JSON file 'chatConfigs.json' not found in the bundle."
                ]
            )
            print("Archivo JSON local no encontrado")
            completion(.failure(error))
            return
        }

        print("Cargando JSON local desde: \(fileURL.lastPathComponent)")

        do {
            let data = try Data(contentsOf: fileURL)
            print("JSON local cargado: \(data.count) bytes")

            if let jsonString = String(data: data, encoding: .utf8) {
                let preview = String(jsonString.prefix(500))
                print("JSON Preview: \(preview)")
            }

            let decodedData = try JSONDecoder().decode(RootConfig.self, from: data)
            print("JSON local decodificado exitosamente")
            completion(.success(decodedData))
        } catch {
            print("Error al cargar o decodificar JSON local: \(error)")
            let loadError = NSError(
                domain: "NetworkService",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey: "Error loading local JSON: \(error.localizedDescription)"
                ]
            )
            completion(.failure(loadError))
        }
    }
}
