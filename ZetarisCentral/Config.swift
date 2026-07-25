import Foundation

enum Config {
    /// Base URL of the Zetaris Central API.
    ///
    /// The iOS Simulator shares the Mac's network, so `localhost` works there.
    /// On a physical device, change this to your Mac's LAN IP, e.g.
    /// `http://192.168.1.20:3030/api/v1`.
    static let apiBaseURL = URL(string: "http://localhost:3030/api/v1")!
}
