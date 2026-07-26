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
    @Published var replyingTo: Comment?
    @Published var editing = false
    @Published var editText = ""

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

    func setReply(_ c: Comment?) { replyingTo = c }

    func addComment() async {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        struct Body: Encodable { let content: String; let parentId: String? }
        do {
            let _: CommentResponse = try await APIClient.shared.post("/posts/\(postId)/comments", body: Body(content: text, parentId: replyingTo?.id))
            commentText = ""
            replyingTo = nil
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't post comment."
        }
        sending = false
    }

    func saveEdit() async {
        struct Body: Encodable { let content: String }
        if let res: PostDetailResponse = try? await APIClient.shared.patch("/posts/\(postId)", body: Body(content: editText)) {
            post = res.post
        }
        editing = false
    }

    func deletePost() async -> Bool {
        do { let _: EmptyResponse = try await APIClient.shared.delete("/posts/\(postId)"); return true }
        catch { return false }
    }
}

struct PostDetailView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: PostDetailViewModel
    @State private var showDelete = false
    @State private var presentViewer = false
    @State private var viewerStart = 0

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
                        if model.editing {
                            VStack(spacing: 8) {
                                TextEditor(text: $model.editText)
                                    .frame(minHeight: 100)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                                HStack {
                                    Button("Cancel") { model.editing = false }
                                    Spacer()
                                    Button("Save") { Task { await model.saveEdit() } }.buttonStyle(.borderedProminent)
                                }
                            }
                        } else if !post.content.isEmpty {
                            RichText(post.content)
                        }
                        ForEach(Array(post.images.enumerated()), id: \.offset) { i, img in
                            AsyncImage(url: Config.mediaURL(img)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Color.gray.opacity(0.1).frame(height: 200)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                            .onTapGesture { openViewer(index: mediaIndex(image: i, post: post)) }
                        }
                        ForEach(Array(post.videos.enumerated()), id: \.offset) { i, video in
                            if let url = Config.mediaURL(video) {
                                VStack(alignment: .leading, spacing: 4) {
                                    VideoPlayerView(url: url).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 12))
                                    if post.mediaItems?.contains(where: { $0.type == "VIDEO" }) == true {
                                        Button { openViewer(index: mediaIndex(video: i, post: post)) } label: {
                                            Label { Text("Comment on this video") } icon: { Lucide("message-circle", size: 16) }
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
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
        .toolbar {
            if let post = model.post, post.author.id == auth.currentUser?.id {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { model.editText = post.content; model.editing = true } label: { Label { Text("Edit") } icon: { Lucide("pencil", size: 16) } }
                        Button(role: .destructive) { showDelete = true } label: { Label { Text("Delete") } icon: { Lucide("trash-2", size: 16) } }
                    } label: { Lucide("ellipsis") }
                }
            }
        }
        .alert("Delete post?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { Task { if await model.deletePost() { dismiss() } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This can't be undone.") }
        .fullScreenCover(isPresented: $presentViewer) {
            if let items = model.post?.mediaItems, !items.isEmpty {
                PostMediaViewer(mediaItems: items, index: viewerStart)
            }
        }
        .task { await model.load() }
    }

    private func openViewer(index: Int) { viewerStart = index; presentViewer = true }

    private func mediaIndex(image i: Int, post: Post) -> Int {
        guard let items = post.mediaItems else { return 0 }
        let imgs = items.enumerated().filter { $0.element.type == "IMAGE" }
        return imgs.indices.contains(i) ? imgs[i].offset : 0
    }
    private func mediaIndex(video i: Int, post: Post) -> Int {
        guard let items = post.mediaItems else { return 0 }
        let vids = items.enumerated().filter { $0.element.type == "VIDEO" }
        return vids.indices.contains(i) ? vids[i].offset : 0
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
                        HStack(spacing: 4) {
                            Text(post.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                            if post.editedAt != nil { Text("· edited").font(.caption).foregroundStyle(.secondary) }
                        }
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
        VStack(alignment: .leading, spacing: 0) {
            if let image = link.image, !image.isEmpty {
                AsyncImage(url: Config.authedMediaURL(image)) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color.gray.opacity(0.1) }
                .frame(maxWidth: .infinity).frame(height: 160).clipped()
            }
            VStack(alignment: .leading, spacing: 2) {
                if let domain = link.domain {
                    Text(domain.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                Text(link.title ?? link.url).font(.subheadline.weight(.semibold)).lineLimit(2)
                if let desc = link.description { Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    Button { Task { await model.react(option.type) } } label: { Text("\(option.emoji)  \(option.label)") }
                }
            } label: {
                Label("\(post.reactions.total)", systemImage: post.reactions.mine != nil ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(post.reactions.mine != nil ? Color.accentColor : Color.secondary)
            }
            Label { Text("\(post.commentCount)") } icon: { Lucide("message-circle", size: 16) }
            Spacer()
            Button { Task { await model.toggleBookmark() } } label: {
                Image(systemName: post.bookmarkedByMe ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(post.bookmarkedByMe ? Color.accentColor : Color.secondary)
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
                        CommentRow(comment: reply, model: model).padding(.leading, 28)
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
                    if !comment.content.isEmpty { RichText(comment.content).font(.subheadline) }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                if !comment.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(comment.images, id: \.self) { img in
                                AsyncImage(url: Config.mediaURL(img)) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.1) }
                                    .frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }

                HStack(spacing: 14) {
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
                    Button("Reply") { model.setReply(comment) }.font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }
}

private struct CommentComposer: View {
    @ObservedObject var model: PostDetailViewModel
    var body: some View {
        Divider()
        if let target = model.replyingTo {
            HStack {
                Text("Replying to \(target.author.name)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { model.setReply(nil) }.font(.caption)
            }
            .padding(.horizontal).padding(.top, 6)
        }
        HStack(spacing: 10) {
            TextField("Add a comment…", text: $model.commentText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await model.addComment() }
            } label: {
                Lucide("send").font(.title2)
            }
            .disabled(model.commentText.trimmingCharacters(in: .whitespaces).isEmpty || model.sending)
        }
        .padding(12)
    }
}
