import SwiftUI

// Reaction types mirror the web (lib/reactions.ts).
let reactionOptions: [(type: String, emoji: String, label: String)] = [
    ("LIKE", "👍", "Like"),
    ("CELEBRATE", "🎉", "Celebrate"),
    ("SUPPORT", "🤝", "Support"),
    ("LOVE", "❤️", "Love"),
    ("INSIGHTFUL", "💡", "Insightful"),
]

@MainActor
final class PostDetailViewModel: ObservableObject {
    let postId: String
    @Published var post: Post?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var commentText = ""
    @Published var sending = false

    init(postId: String) { self.postId = postId }

    func load() async {
        do {
            let res: PostDetailResponse = try await APIClient.shared.get("/posts/\(postId)")
            post = res.post
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load the post."
        }
        isLoading = false
    }

    func react(_ type: String) async {
        let _: ReactResponse? = try? await APIClient.shared.post("/posts/\(postId)/react", body: ["type": type])
        await load()
    }

    func toggleBookmark() async {
        let _: BookmarkResponse? = try? await APIClient.shared.post("/posts/\(postId)/bookmark")
        await load()
    }

    func toggleCommentLike(_ id: String) async {
        let _: LikeResponse? = try? await APIClient.shared.post("/comments/\(id)/like")
        await load()
    }

    func addComment() async {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        do {
            let _: CommentResponse = try await APIClient.shared.post("/posts/\(postId)/comments", body: ["content": text])
            commentText = ""
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't post comment."
        }
        sending = false
    }
}

struct PostDetailView: View {
    @StateObject private var model: PostDetailViewModel

    init(postId: String) {
        _model = StateObject(wrappedValue: PostDetailViewModel(postId: postId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if let post = model.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PostHeader(post: post)
                        if !post.content.isEmpty {
                            Text(post.content).font(.body)
                        }
                        if let link = post.link { LinkCardView(link: link) }
                        ActionBar(post: post, model: model)
                        Divider()
                        CommentsSection(comments: post.comments ?? [], model: model)
                    }
                    .padding(16)
                }
                CommentComposer(model: model)
            } else {
                ContentUnavailableViewCompat(title: "Not found", message: model.errorMessage ?? "This post is unavailable.")
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

private struct PostHeader: View {
    let post: Post
    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(value: AppRoute.profile(post.author.id)) {
                HStack(spacing: 10) {
                    AvatarView(name: post.author.name, url: post.author.avatarUrl)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.author.name).font(.subheadline.weight(.semibold))
                        Text(post.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}

private struct LinkCardView: View {
    let link: LinkCard
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let domain = link.domain {
                Text(domain.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(link.title ?? link.url).font(.subheadline.weight(.semibold)).lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ActionBar: View {
    let post: Post
    @ObservedObject var model: PostDetailViewModel
    var body: some View {
        HStack(spacing: 18) {
            Menu {
                ForEach(reactionOptions, id: \.type) { option in
                    Button {
                        Task { await model.react(option.type) }
                    } label: {
                        Text("\(option.emoji)  \(option.label)")
                    }
                }
            } label: {
                Label(
                    "\(post.reactions.total)",
                    systemImage: post.reactions.mine != nil ? "hand.thumbsup.fill" : "hand.thumbsup"
                )
            }
            Label("\(post.commentCount)", systemImage: "bubble.left")
            Spacer()
            Button {
                Task { await model.toggleBookmark() }
            } label: {
                Image(systemName: post.bookmarkedByMe ? "bookmark.fill" : "bookmark")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

private struct CommentsSection: View {
    let comments: [Comment]
    @ObservedObject var model: PostDetailViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comments").font(.headline)
            if comments.isEmpty {
                Text("No comments yet. Be the first.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, model: model)
                    ForEach(comment.replies ?? []) { reply in
                        CommentRow(comment: reply, model: model)
                            .padding(.leading, 28)
                    }
                }
            }
        }
    }
}

private struct CommentRow: View {
    let comment: Comment
    @ObservedObject var model: PostDetailViewModel
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink(value: AppRoute.profile(comment.author.id)) {
                AvatarView(name: comment.author.name, url: comment.author.avatarUrl, size: 32)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.author.name).font(.subheadline.weight(.semibold))
                    Text(comment.content).font(.subheadline)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                Button {
                    Task { await model.toggleCommentLike(comment.id) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: comment.likedByMe ? "heart.fill" : "heart")
                        if comment.likeCount > 0 { Text("\(comment.likeCount)") }
                    }
                    .font(.caption)
                    .foregroundStyle(comment.likedByMe ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
    }
}

private struct CommentComposer: View {
    @ObservedObject var model: PostDetailViewModel
    var body: some View {
        Divider()
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $model.commentText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await model.addComment() }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(model.commentText.trimmingCharacters(in: .whitespaces).isEmpty || model.sending)
        }
        .padding(12)
    }
}
