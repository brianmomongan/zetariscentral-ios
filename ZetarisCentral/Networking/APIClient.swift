import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case server(String)
    case decoding
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Your session has expired. Please sign in again."
        case .server(let m): return m
        case .decoding: return "Unexpected response from the server."
        case .transport(let m): return m
        }
    }
}

/// Thin JSON client for the Zetaris Central API. Attaches the Bearer token to
/// every request via the shared `TokenStore`.
struct APIClient {
    static let shared = APIClient()

    private let session = URLSession.shared

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        // The API emits ISO-8601 with fractional seconds (e.g. 2026-07-25T05:00:00.000Z).
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            if let date = formatter.date(from: s) ?? plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(s)")
        }
        return d
    }

    // MARK: - Requests

    func get<T: Decodable>(_ path: String, auth: Bool = true) async throws -> T {
        try await request(path, method: "GET", body: Optional<Int>.none, auth: auth)
    }

    @discardableResult
    func post<T: Decodable, B: Encodable>(_ path: String, body: B, auth: Bool = true) async throws -> T {
        try await request(path, method: "POST", body: body, auth: auth)
    }

    /// POST with no request body (for toggle-style endpoints).
    @discardableResult
    func post<T: Decodable>(_ path: String, auth: Bool = true) async throws -> T {
        try await request(path, method: "POST", body: Optional<Int>.none, auth: auth)
    }

    @discardableResult
    func delete<T: Decodable>(_ path: String, auth: Bool = true) async throws -> T {
        try await request(path, method: "DELETE", body: Optional<Int>.none, auth: auth)
    }

    @discardableResult
    func patch<T: Decodable, B: Encodable>(_ path: String, body: B, auth: Bool = true) async throws -> T {
        try await request(path, method: "PATCH", body: body, auth: auth)
    }

    private func request<T: Decodable, B: Encodable>(
        _ path: String, method: String, body: B?, auth: Bool
    ) async throws -> T {
        var url = Config.apiBaseURL
        url.append(path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        if auth, let token = TokenStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorBody.self, from: data))?.error
                ?? "Request failed (\(http.statusCode))."
            throw APIError.server(message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

/// Placeholder for endpoints that don't need a typed reply.
struct EmptyResponse: Decodable {}
