import Foundation

enum Config {
    /// Base URL of the Zetaris Central API.
    ///
    /// The iOS Simulator shares the Mac's network, so `localhost` works there.
    /// On a physical device, change this to your Mac's LAN IP, e.g.
    /// `http://192.168.1.20:3030/api/v1`.
    static let apiBaseURL = URL(string: "http://localhost:3030/api/v1")!

    /// Origin (no path) for building non-v1 URLs like file downloads.
    static let apiOrigin = URL(string: "http://localhost:3030")!

    /// A tokenized URL for opening/previewing a file's bytes in the browser.
    static func fileURL(_ id: String) -> URL {
        var url = apiOrigin
        url.append(path: "/api/files/\(id)/download")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "inline", value: "1"),
            URLQueryItem(name: "token", value: TokenStore.shared.token ?? ""),
        ]
        return comps.url ?? url
    }
}
