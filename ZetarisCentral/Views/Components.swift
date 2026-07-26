import SwiftUI
import AVKit

/// Renders body text with @mentions / #hashtags (accent-colored) and tappable
/// links, matching the web's RichText. (Mention/hashtag navigation is wired via
/// the custom URL scheme handler.)
struct RichText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(Self.attributed(text))
            .tint(Theme.sky)
    }

    static func attributed(_ s: String) -> AttributedString {
        var result = AttributedString()
        let pattern = try? NSRegularExpression(pattern: "@[A-Za-z0-9_.]+|#[A-Za-z0-9_]+|https?://[^\\s]+")
        let ns = s as NSString
        var last = 0
        pattern?.enumerateMatches(in: s, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            if match.range.location > last {
                result += AttributedString(ns.substring(with: NSRange(location: last, length: match.range.location - last)))
            }
            let token = ns.substring(with: match.range)
            var run = AttributedString(token)
            run.foregroundColor = Theme.sky
            if token.hasPrefix("http"), let url = URL(string: token) {
                run.link = url
            } else if token.hasPrefix("@") {
                run.link = URL(string: "zetariscentral://profile/\(token.dropFirst().trimmingCharacters(in: CharacterSet(charactersIn: ".")))")
            } else if token.hasPrefix("#") {
                run.link = URL(string: "zetariscentral://tag/\(token.dropFirst())")
            }
            result += run
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            result += AttributedString(ns.substring(from: last))
        }
        return result
    }
}

/// Inline video player (AVKit).
struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { if player == nil { player = AVPlayer(url: url) } }
            .onDisappear { player?.pause() }
    }
}

/// Identifiable String wrapper for `.sheet(item:)`.
struct IdentifiedString: Identifiable { let value: String; var id: String { value } }

/// Centered empty-state placeholder (title + optional hint).
struct EmptyStateView: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}
