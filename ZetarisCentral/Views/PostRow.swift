import SwiftUI

struct PostRow: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AvatarView(name: post.author.name, url: post.author.avatarUrl)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(post.author.name).font(.subheadline.weight(.semibold))
                        if post.isAnnouncement {
                            Text("Announcement")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.yellow.opacity(0.25), in: Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        Text(post.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                        if let audience = post.audience {
                            Text("· \(audience.kind == "PRIVATE" ? "Only you" : (audience.label ?? ""))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }

            if !post.content.isEmpty {
                Text(post.content).font(.body)
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

            if !post.videos.isEmpty {
                Label("\(post.videos.count) video\(post.videos.count == 1 ? "" : "s")", systemImage: "play.rectangle.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let link = post.link {
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

            HStack(spacing: 18) {
                Label("\(post.reactions.total)", systemImage: post.reactions.mine != nil ? "hand.thumbsup.fill" : "hand.thumbsup")
                Label("\(post.commentCount)", systemImage: "bubble.left")
                if post.bookmarkedByMe { Image(systemName: "bookmark.fill") }
                Spacer()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct AvatarView: View {
    let name: String
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
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
