import SwiftUI

struct ReactionType: Identifiable {
    var id: String { type }
    let type: String
    let emoji: String
    let label: String
}

let reactionTypes: [ReactionType] = [
    .init(type: "LIKE", emoji: "👍", label: "Like"),
    .init(type: "CELEBRATE", emoji: "🎉", label: "Celebrate"),
    .init(type: "SUPPORT", emoji: "🤝", label: "Support"),
    .init(type: "LOVE", emoji: "❤️", label: "Love"),
    .init(type: "INSIGHTFUL", emoji: "💡", label: "Insightful"),
]

func reactionEmoji(_ type: String) -> String { reactionTypes.first { $0.type == type }?.emoji ?? "👍" }
func reactionLabel(_ type: String?) -> String {
    guard let type, let rt = reactionTypes.first(where: { $0.type == type }) else { return "Like" }
    return rt.label
}

struct PostRow: View {
    let post: Post
    @State private var mine: String?
    @State private var total: Int
    @State private var bookmarked: Bool
    @State private var fileToView: FileRef?

    init(post: Post) {
        self.post = post
        _mine = State(initialValue: post.reactions.mine)
        _total = State(initialValue: post.reactions.total)
        _bookmarked = State(initialValue: post.bookmarkedByMe)
    }

    // Body with internal file links (/f/<id>) removed — shown as the chip instead.
    private var bodyText: String {
        post.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.contains("/f/") }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    private var fileLink: LinkCard? { post.link.flatMap { $0.url.contains("/f/") ? $0 : nil } }
    private func fileId(_ link: LinkCard) -> String {
        (link.url.split(separator: "/").last.map(String.init) ?? "").components(separatedBy: "?").first ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if post.isAnnouncement {
                Label("Announcement", systemImage: "megaphone.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.announce)
            }
            if post.pinned {
                Label("Pinned", systemImage: "pin.fill").font(.caption2).foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                AvatarView(name: post.author.name, url: post.author.avatarUrl)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(post.author.name).font(.subheadline.weight(.semibold))
                        if let audience = post.audience {
                            Text("· \(audience.kind == "PRIVATE" ? "Only you" : (audience.label ?? ""))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(post.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                        if post.editedAt != nil { Text("· edited").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Spacer()
            }

            if !bodyText.isEmpty {
                RichText(bodyText)
            }

            if let link = fileLink {
                Button {
                    fileToView = FileRef(id: fileId(link), name: link.title ?? "file")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: (link.image?.isEmpty == false) ? "photo" : "doc.text")
                        Text(link.title ?? "File").font(.subheadline.weight(.medium)).lineLimit(1)
                        if let size = link.description?.components(separatedBy: " · ").first, !size.isEmpty {
                            Text("· \(size)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.borderless)
            }

            if !post.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(post.images, id: \.self) { img in
                            AsyncImage(url: Config.mediaURL(img)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.1)
                            }
                            .frame(width: 220, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            ForEach(post.videos, id: \.self) { video in
                if let url = Config.mediaURL(video) {
                    VideoPlayerView(url: url)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if let link = post.link, fileLink == nil {
                VStack(alignment: .leading, spacing: 0) {
                    if let image = link.image, !image.isEmpty {
                        AsyncImage(url: Config.authedMediaURL(image)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color.gray.opacity(0.1) }
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if let domain = link.domain {
                            Text(domain.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text(link.title ?? link.url).font(.subheadline.weight(.semibold)).lineLimit(2)
                        if let desc = link.description {
                            Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }

            // Summary
            if total > 0 || post.commentCount > 0 {
                HStack {
                    if total > 0 {
                        let emojis = (post.reactions.byType.filter { $0.count > 0 }.map { reactionEmoji($0.type) }).joined()
                        Text("\(emojis) \(total)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if post.commentCount > 0 {
                        Text("\(post.commentCount) comment\(post.commentCount == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack {
                Menu {
                    ForEach(reactionTypes) { rt in
                        Button { Task { await react(rt.type) } } label: { Text("\(rt.emoji)  \(rt.label)") }
                    }
                } label: {
                    Label(reactionLabel(mine), systemImage: mine != nil ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundStyle(mine != nil ? Color.accentColor : Color.secondary)
                } primaryAction: {
                    Task { await react(mine ?? "LIKE") }
                }
                .buttonStyle(.borderless)

                Spacer()
                Label("Comment", systemImage: "bubble.left").foregroundStyle(.secondary)
                Spacer()

                Button { Task { await toggleBookmark() } } label: {
                    Label(bookmarked ? "Saved" : "Save", systemImage: bookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(bookmarked ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
            }
            .font(.footnote)
        }
        .padding(.vertical, 6)
        .sheet(item: $fileToView) { ref in FileViewerSheet(fileId: ref.id, name: ref.name) }
    }

    private func react(_ type: String) async {
        let prevMine = mine, prevTotal = total
        let next = (mine == type) ? nil : type
        mine = next
        total = prevTotal + (next != nil ? 1 : 0) - (prevMine != nil ? 1 : 0)
        struct Body: Encodable { let type: String }
        do {
            let res: ReactResponse = try await APIClient.shared.post("/posts/\(post.id)/react", body: Body(type: type))
            mine = res.mine
        } catch {
            mine = prevMine; total = prevTotal
        }
    }

    private func toggleBookmark() async {
        let prev = bookmarked
        bookmarked = !prev
        struct Resp: Decodable { let bookmarked: Bool }
        do {
            let res: Resp = try await APIClient.shared.post("/posts/\(post.id)/bookmark")
            bookmarked = res.bookmarked
        } catch {
            bookmarked = prev
        }
    }
}

struct AvatarView: View {
    let name: String
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url, !url.isEmpty, let u = Config.mediaURL(url) {
                AsyncImage(url: u) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsCircle
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsCircle: some View {
        Circle()
            .fill(.tint.opacity(0.2))
            .overlay(Text(initials).font(.subheadline.weight(.semibold)).foregroundStyle(.tint))
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
