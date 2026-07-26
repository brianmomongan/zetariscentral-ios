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
                .tabItem { Label("Home", systemImage: "house") }
            SpacesView()
                .tabItem { Label("Spaces", systemImage: "number") }
            EventsView()
                .tabItem { Label("Events", systemImage: "calendar") }
            NotificationsView()
                .tabItem { Label("Activity", systemImage: "bell") }
            ConversationsView()
                .tabItem { Label("Messages", systemImage: "message") }
        }
    }
}
