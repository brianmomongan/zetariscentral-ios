import SwiftUI

/// Bookmarked posts (GET /saved).
struct SavedView: View {
    @State private var posts: [Post] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if posts.isEmpty {
                EmptyStateView(title: "Nothing saved yet.", subtitle: "Tap Save on a post to keep it here.")
            } else {
                List(posts) { post in
                    NavigationLink(value: AppRoute.post(post.id)) { PostRow(post: post) }
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved")
        .task {
            if let res: FeedResponse = try? await APIClient.shared.get("/saved") { posts = res.posts }
            loading = false
        }
    }
}

/// Posts for a #hashtag (GET /tag/{tag}).
struct TagView: View {
    let tag: String
    @State private var posts: [Post] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if posts.isEmpty {
                EmptyStateView(title: "No posts", subtitle: "Nothing tagged #\(tag) yet.")
            } else {
                List(posts) { post in
                    NavigationLink(value: AppRoute.post(post.id)) { PostRow(post: post) }
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("#\(tag)")
        .task {
            let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
            if let res: FeedResponse = try? await APIClient.shared.get("/tag/\(encoded)") { posts = res.posts }
            loading = false
        }
    }
}

/// Followers or following list (GET /people/[id]/followers|following).
struct PeopleListView: View {
    let userId: String
    let mode: String
    @State private var people: [PersonRef] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if people.isEmpty {
                EmptyStateView(title: mode == "followers" ? "No followers yet." : "Not following anyone yet.")
            } else {
                List(people) { person in
                    NavigationLink(value: AppRoute.profile(person.id)) {
                        HStack(spacing: 12) {
                            AvatarView(name: person.name, url: person.avatarUrl)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(person.name).font(.subheadline.weight(.semibold))
                                if let title = person.title { Text(title).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(mode == "followers" ? "Followers" : "Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let res: PeopleResponse = try? await APIClient.shared.get("/people/\(userId)/\(mode)") { people = res.people }
            loading = false
        }
    }
}

/// People directory (GET /people[?q=]).
struct DirectoryView: View {
    @State private var query = ""
    @State private var people: [PersonRef] = []
    @State private var loading = true

    var body: some View {
        List {
            ForEach(people) { person in
                NavigationLink(value: AppRoute.profile(person.id)) {
                    HStack(spacing: 12) {
                        AvatarView(name: person.name, url: person.avatarUrl)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person.name).font(.subheadline.weight(.semibold))
                            if let title = person.title { Text(title).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay { if loading { ProgressView() } else if people.isEmpty { EmptyStateView(title: "No people found.") } }
        .searchable(text: $query)
        .onChange(of: query) { _ in Task { await load() } }
        .navigationTitle("People")
        .task { await load() }
    }

    private func load() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        let path = q.isEmpty ? "/people" : "/people?q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)"
        if let res: PeopleResponse = try? await APIClient.shared.get(path) { people = res.people }
        loading = false
    }
}
