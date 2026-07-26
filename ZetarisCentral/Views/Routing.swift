import SwiftUI

/// Every push destination in the app. Each tab's NavigationStack registers a
/// single `.navigationDestination(for: AppRoute.self)` using `destinationView`,
/// so any screen can link to any other.
enum AppRoute: Hashable {
    case post(String)          // post id
    case conversation(String)  // conversation id
    case space(String)         // slug
    case profile(String)       // user id
    case event(String)         // event id
    case groups                // groups list
    case group(String)         // group id
    case news                  // news screen
    case settings              // edit profile
    case search                // search screen
    case files                 // files browser
}

@ViewBuilder
func destinationView(for route: AppRoute) -> some View {
    switch route {
    case .post(let id): PostDetailView(postId: id)
    case .conversation(let id): ConversationView(conversationId: id)
    case .space(let slug): SpaceDetailView(slug: slug)
    case .profile(let id): ProfileView(userId: id)
    case .event(let id): EventDetailView(eventId: id)
    case .groups: GroupsView()
    case .group(let id): GroupDetailView(groupId: id)
    case .news: NewsView()
    case .settings: SettingsView()
    case .search: SearchView()
    case .files: FilesView()
    }
}
