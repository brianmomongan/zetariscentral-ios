import SwiftUI

@main
struct ZetarisCentralApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .onOpenURL { url in
                    guard url.scheme == "zetariscentral" else { return }
                    if url.host == "tab", let n = Int(url.lastPathComponent) {
                        TabRouter.shared.selection = n
                        return
                    }
                    guard url.host == "auth" else { return }
                    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                    if let token = items?.first(where: { $0.name == "token" })?.value {
                        auth.onExternalToken(token)
                    } else if let err = items?.first(where: { $0.name == "error" })?.value {
                        auth.onExternalError(err)
                    }
                }
        }
    }
}
