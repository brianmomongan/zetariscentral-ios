import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        if auth.isAuthenticated {
            FeedView()
        } else {
            LoginView()
        }
    }
}
