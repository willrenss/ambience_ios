import Foundation

enum APIError: Error, Sendable {
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case noToken
    case unknown(Error)
}

actor APIClient {
    static let shared = APIClient()

    private var authToken: String?
    // Read saved URL from UserDefaults on init; fall back to hardcoded default.
    private var baseURLString: String =
        UserDefaults.standard.string(forKey: serverURLKey) ?? serverFallbackURL

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy  = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {}

    func setToken(_ token: String)  { authToken = token }
    func clearToken()               { authToken = nil }
    func updateBaseURL(_ url: String) { baseURLString = url }

    // MARK: - Request builders

    private var baseURL: URL {
        URL(string: baseURLString) ?? URL(string: serverFallbackURL)!
    }

    private func makeRequest(method: String, path: String, body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode)
        }
        return data
    }

    // MARK: - Public methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(method: "GET", path: path)
        let data    = try await perform(request)
        do    { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decodingError(error) }
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request  = try makeRequest(method: "POST", path: path, body: bodyData)
        let data     = try await perform(request)
        do    { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decodingError(error) }
    }

    func post(_ path: String, body: some Encodable) async throws {
        let bodyData = try encoder.encode(body)
        let request  = try makeRequest(method: "POST", path: path, body: bodyData)
        _ = try await perform(request)
    }

    func patch(_ path: String, body: some Encodable) async throws {
        let bodyData = try encoder.encode(body)
        let request  = try makeRequest(method: "PATCH", path: path, body: bodyData)
        _ = try await perform(request)
    }

    func delete(_ path: String) async throws {
        let request = try makeRequest(method: "DELETE", path: path)
        _ = try await perform(request)
    }

    func webSocketURL(path: String) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "ws"
        components.path   = path
        if let token = authToken {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        return components.url
    }
}
