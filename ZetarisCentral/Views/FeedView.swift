import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var groups: [GroupSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = posts.isEmpty
        errorMessage = nil
        do {
            let res: FeedResponse = try await APIClient.shared.get("/feed")
            posts = res.posts
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load the feed."
        }
        isLoading = false
        if let res: GroupsResponse = try? await APIClient.shared.get("/groups") { groups = res.groups }
    }

    func createPost(_ content: String, visibility: String, groupId: String?) async -> Bool {
        struct Body: Codable { let content: String; let visibility: String; let groupId: String? }
        do {
            let _: CreatePostResponse = try await APIClient.shared.post("/posts", body: Body(content: content, visibility: visibility, groupId: groupId))
            await load()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't post."
            return false
        }
    }
}

struct FeedView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var model = FeedViewModel()
    @State private var showComposer = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if let error = model.errorMessage, model.posts.isEmpty {
                    ContentUnavailableViewCompat(title: "Couldn't load", message: error)
                } else {
                    List(model.posts) { post in
                        NavigationLink(value: AppRoute.post(post.id)) {
                            PostRow(post: post)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let id = auth.currentUser?.id {
                            Button { path.append(AppRoute.profile(id)) } label: { Label("My profile", systemImage: "person") }
                        }
                        Button { path.append(AppRoute.search) } label: { Label("Search", systemImage: "magnifyingglass") }
                        Button { path.append(AppRoute.news) } label: { Label("News", systemImage: "newspaper") }
                        Button { path.append(AppRoute.files) } label: { Label("Files", systemImage: "folder") }
                        Button { path.append(AppRoute.groups) } label: { Label("Groups", systemImage: "person.2") }
                        Button { path.append(AppRoute.settings) } label: { Label("Settings", systemImage: "gear") }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showComposer = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showComposer) {
                ComposerView(groups: model.groups) { content, visibility, groupId in
                    let ok = await model.createPost(content, visibility: visibility, groupId: groupId)
                    if ok { showComposer = false }
                }
            }
            .task { await model.load() }
        }
    }
}

private struct ComposerView: View {
    let groups: [GroupSummary]
    let onPost: (_ content: String, _ visibility: String, _ groupId: String?) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var audience = "COMPANY" // COMPANY | PRIVATE | group:<id>
    @State private var posting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Menu {
                        Button { audience = "COMPANY" } label: { Label("Everyone", systemImage: "globe") }
                        Button { audience = "PRIVATE" } label: { Label("Only me", systemImage: "lock") }
                        if !groups.isEmpty {
                            Divider()
                            ForEach(groups) { group in
                                Button { audience = "group:\(group.id)" } label: { Label(group.name, systemImage: "person.2") }
                            }
                        }
                    } label: {
                        Label(audienceLabel, systemImage: audienceIcon).font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.horizontal).padding(.top, 8)
                TextEditor(text: $text).padding(8)
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        posting = true
                        let visibility = audience == "PRIVATE" ? "PRIVATE" : audience.hasPrefix("group:") ? "GROUP" : "COMPANY"
                        let groupId = audience.hasPrefix("group:") ? String(audience.dropFirst(6)) : nil
                        Task { await onPost(text, visibility, groupId); posting = false }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || posting)
                }
            }
        }
    }

    private var audienceLabel: String {
        if audience == "PRIVATE" { return "Only me" }
        if audience.hasPrefix("group:"), let g = groups.first(where: { "group:\($0.id)" == audience }) { return g.name }
        return "Everyone"
    }
    private var audienceIcon: String {
        if audience == "PRIVATE" { return "lock" }
        if audience.hasPrefix("group:") { return "person.2" }
        return "globe"
    }
}

/// Small back-compat helper so the app builds on iOS 16 (ContentUnavailableView
/// is iOS 17+).
struct ContentUnavailableViewCompat: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}
