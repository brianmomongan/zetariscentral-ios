import SwiftUI

/// Holds the selected bottom-tab so deep links (`zetariscentral://tab/<n>`) can
/// switch tabs.
final class TabRouter: ObservableObject {
    static let shared = TabRouter()
    @Published var selection = 0
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @AppStorage("theme_mode") private var themeMode = "system"

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .tint(Theme.sky)
        .preferredColorScheme(themeMode == "light" ? .light : themeMode == "dark" ? .dark : nil)
    }
}

struct MainTabView: View {
    @ObservedObject private var router = TabRouter.shared

    var body: some View {
        TabView(selection: $router.selection) {
            FeedView()
                .tabItem { Label("Home", image: "lucide-house") }.tag(0)
            SpacesView()
                .tabItem { Label("Spaces", image: "lucide-hash") }.tag(1)
            EventsView()
                .tabItem { Label("Events", image: "lucide-calendar-days") }.tag(2)
            NotificationsView()
                .tabItem { Label("Activity", image: "lucide-bell") }.tag(3)
            ConversationsView()
                .tabItem { Label("Messages", image: "lucide-message-circle") }.tag(4)
        }
    }
}
