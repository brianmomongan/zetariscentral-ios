import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
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
    }

    func createPost(_ content: String) async -> Bool {
        do {
            let _: CreatePostResponse = try await APIClient.shared.post("/posts", body: ["content": content])
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

    var body: some View {
        NavigationStack {
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
                    Button("Sign out") { auth.logout() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let id = auth.currentUser?.id {
                        NavigationLink(value: AppRoute.profile(id)) {
                            Image(systemName: "person.circle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showComposer = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showComposer) {
                ComposerView { content in
                    let ok = await model.createPost(content)
                    if ok { showComposer = false }
                }
            }
            .task { await model.load() }
        }
    }
}

private struct ComposerView: View {
    let onPost: (String) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var posting = false

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("New post")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Post") {
                            posting = true
                            Task { await onPost(text); posting = false }
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || posting)
                    }
                }
        }
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
