import Foundation

enum Config {
    private static let originKey = "server_origin"

    /// The iOS Simulator shares the Mac's network, so `localhost` works there.
    /// On a physical device, set your Mac's LAN IP in Settings → Server.
    private static let defaultOrigin = "http://localhost:3030"

    /// Current server origin (no path). Settable at runtime.
    static var origin: String {
        UserDefaults.standard.string(forKey: originKey) ?? defaultOrigin
    }

    static func setOrigin(_ value: String) {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while v.hasSuffix("/") { v = String(v.dropLast()) }
        UserDefaults.standard.set(v, forKey: originKey)
    }

    static var apiBaseURL: URL { URL(string: "\(origin)/api/v1")! }
    static var apiOrigin: URL { URL(string: origin)! }

    /// Resolve a possibly-relative media path (e.g. "/uploads/x.png") to absolute.
    static func mediaURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "\(origin)\(path)")
    }

    /// A tokenized URL for a file's bytes (authenticated /api/files download).
    static func fileURL(_ id: String) -> URL {
        var comps = URLComponents(string: "\(origin)/api/files/\(id)/download")!
        comps.queryItems = [
            URLQueryItem(name: "inline", value: "1"),
            URLQueryItem(name: "token", value: TokenStore.shared.token ?? ""),
        ]
        return comps.url!
    }

    /// Like `mediaURL`, but appends the auth token for authenticated file-download
    /// URLs (`/api/files/.../download`). Public `/uploads/...` paths are unchanged.
    static func authedMediaURL(_ path: String) -> URL? {
        guard let base = mediaURL(path) else { return nil }
        let s = base.absoluteString
        guard s.contains("/api/files/"), s.contains("/download") else { return base }
        let sep = s.contains("?") ? "&" : "?"
        return URL(string: "\(s)\(sep)token=\(TokenStore.shared.token ?? "")")
    }
}
