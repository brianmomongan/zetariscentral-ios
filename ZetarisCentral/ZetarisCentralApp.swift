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
                    if url.host == "open" {
                        let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "q" })?.value ?? ""
                        let route: AppRoute?
                        switch url.lastPathComponent {
                        case "files": route = .files
                        case "search": route = .search
                        case "directory", "people": route = .directory
                        case "saved": route = .saved
                        case "news": route = .news
                        case "profile": route = q.isEmpty ? nil : .profile(q)
                        case "group": route = q.isEmpty ? nil : .group(q)
                        default: route = nil
                        }
                        if let route {
                            TabRouter.shared.selection = 0
                            TabRouter.shared.seedQuery = q
                            TabRouter.shared.pendingRoute = route
                        }
                        return
                    }
                    if url.host == "feed" {
                        TabRouter.shared.selection = 0
                        TabRouter.shared.pendingFilter = url.lastPathComponent
                        return
                    }
                    if url.host == "conversation" {
                        TabRouter.shared.selection = 4
                        TabRouter.shared.pendingConversation = url.lastPathComponent
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
