import SwiftUI

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
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Home", image: "lucide-house") }
            SpacesView()
                .tabItem { Label("Spaces", image: "lucide-hash") }
            EventsView()
                .tabItem { Label("Events", image: "lucide-calendar-days") }
            NotificationsView()
                .tabItem { Label("Activity", image: "lucide-bell") }
            ConversationsView()
                .tabItem { Label("Messages", image: "lucide-message-circle") }
        }
    }
}
