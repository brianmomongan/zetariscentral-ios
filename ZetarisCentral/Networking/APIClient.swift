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

    /// Multipart upload of a photo/video to /upload; returns { url, type }.
    func uploadMedia(_ data: Data, filename: String, mimeType: String) async throws -> MediaRef {
        var url = Config.apiBaseURL
        url.append(path: "/upload")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = TokenStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (respData, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server("Upload failed.")
        }
        return try JSONDecoder().decode(MediaRef.self, from: respData)
    }

    /// Upload a file into a drive folder (the non-v1 /api/files/upload route).
    func uploadFileToDrive(_ data: Data, filename: String, mimeType: String, drive: String, parentId: String?) async throws {
        var url = Config.apiOrigin
        url.append(path: "/api/files/upload")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = TokenStore.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        addField("drive", drive)
        if let parentId { addField("parentId", parentId) }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server("Upload failed.")
        }
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
