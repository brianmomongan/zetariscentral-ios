import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        if auth.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Home", systemImage: "house") }
            SpacesView()
                .tabItem { Label("Spaces", systemImage: "number") }
            NotificationsView()
                .tabItem { Label("Activity", systemImage: "bell") }
            ConversationsView()
                .tabItem { Label("Messages", systemImage: "message") }
        }
    }
}
