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
    case saved                 // bookmarked posts
    case directory             // people directory
    case tag(String)           // hashtag
    case followers(String)     // user id
    case following(String)     // user id
}

/// Intercepts the `zetariscentral://profile/…` and `…/tag/…` links that RichText
/// emits and pushes them onto this stack's path; real links open normally.
struct RouteLinkHandler: ViewModifier {
    @Binding var path: NavigationPath
    func body(content: Content) -> some View {
        content.environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "zetariscentral" else { return .systemAction }
            let arg = url.pathComponents.dropFirst().first
            switch url.host {
            case "profile": if let arg { path.append(AppRoute.profile(arg)) }; return .handled
            case "tag": if let arg { path.append(AppRoute.tag(arg)) }; return .handled
            default: return .systemAction
            }
        })
    }
}

extension View {
    func handlesRouteLinks(_ path: Binding<NavigationPath>) -> some View { modifier(RouteLinkHandler(path: path)) }
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
    case .saved: SavedView()
    case .directory: DirectoryView()
    case .tag(let tag): TagView(tag: tag)
    case .followers(let id): PeopleListView(userId: id, mode: "followers")
    case .following(let id): PeopleListView(userId: id, mode: "following")
    }
}
