import SwiftUI

/// Full-screen media viewer with a per-photo/-video comment thread (like the web).
struct PostMediaViewer: View {
    let mediaItems: [MediaItem]
    @State var index: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $index) {
                    ForEach(Array(mediaItems.enumerated()), id: \.offset) { i, item in
                        Group {
                            if item.type == "VIDEO", let url = Config.mediaURL(item.url) {
                                VideoPlayerView(url: url)
                            } else {
                                AsyncImage(url: Config.mediaURL(item.url)) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: { ProgressView() }
                            }
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: mediaItems.count > 1 ? .automatic : .never))
                .background(Color.black)
                .frame(maxHeight: .infinity)

                Divider()
                MediaComments(mediaId: mediaItems[safe: index]?.id ?? mediaItems[0].id)
                    .frame(maxHeight: 320)
            }
            .navigationTitle(mediaItems.count > 1 ? "\(index + 1) / \(mediaItems.count)" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct MediaComments: View {
    let mediaId: String
    @State private var comments: [Comment] = []
    @State private var text = ""
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if comments.isEmpty {
                EmptyStateView(title: "No comments yet.", subtitle: "Be the first to comment on this.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 10) {
                                AvatarView(name: comment.author.name, url: comment.author.avatarUrl, size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(comment.author.name).font(.caption.weight(.semibold))
                                    if !comment.content.isEmpty { RichText(comment.content).font(.subheadline) }
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(12)
                }
            }
            Divider()
            HStack(spacing: 10) {
                TextField("Add a comment…", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(1...3)
                Button {
                    Task { await send() }
                } label: { Lucide("send").font(.title2) }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
        }
        .task(id: mediaId) { loading = true; await load() }
    }

    private func load() async {
        if let res: MediaCommentsResponse = try? await APIClient.shared.get("/media/\(mediaId)/comments") {
            comments = res.comments
        }
        loading = false
    }

    private func send() async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        text = ""
        let _: CommentResponse? = try? await APIClient.shared.post("/media/\(mediaId)/comments", body: ["content": t])
        await load()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
