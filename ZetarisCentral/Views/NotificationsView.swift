import SwiftUI

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load() async {
        do {
            let res: NotificationsResponse = try await APIClient.shared.get("/notifications")
            notifications = res.notifications
            // Opening the screen marks everything read (mirrors the web).
            let _: EmptyResponse? = try? await APIClient.shared.post("/notifications/read")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load notifications."
        }
        isLoading = false
    }
}

struct NotificationsView: View {
    @StateObject private var model = NotificationsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if model.notifications.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "You're all caught up",
                        message: model.errorMessage ?? "Notifications will show up here."
                    )
                } else {
                    List(model.notifications) { note in
                        NavigationLink(value: route(for: note)) { NotificationRow(note: note) }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle("Notifications")
            .task { await model.load() }
        }
    }

    private func route(for note: AppNotification) -> AppRoute {
        if let postId = note.postId { return .post(postId) }
        if let convoId = note.conversationId { return .conversation(convoId) }
        return .profile(note.actor.id) // FOLLOW / other actor-centric notifications
    }
}

private struct NotificationRow: View {
    let note: AppNotification

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: note.actor.name, url: note.actor.avatarUrl, size: 40)
            Text(attributedText)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if !note.read {
                Circle().fill(.tint).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    /// "<Name> <verb> · <time>", with an event-first phrasing for reminders.
    private var attributedText: AttributedString {
        var result = AttributedString()
        if note.type == "EVENT_REMINDER" {
            var title = AttributedString(note.event?.title ?? "An event")
            title.font = .subheadline.weight(.semibold)
            result += title
            result += AttributedString(" is starting soon")
        } else {
            var name = AttributedString(note.actor.name)
            name.font = .subheadline.weight(.semibold)
            result += name
            result += AttributedString(" \(verb)")
        }
        var time = AttributedString("  ·  \(note.createdAt.formatted(.relative(presentation: .named)))")
        time.font = .caption
        time.foregroundColor = .secondary
        result += time
        return result
    }

    private var verb: String {
        switch note.type {
        case "COMMENT": return "commented on your post"
        case "REPLY": return "replied to your comment"
        case "REACTION": return "reacted to your post"
        case "MENTION": return "mentioned you"
        case "FOLLOW": return "started following you"
        case "MESSAGE": return "sent you a message"
        case "EVENT": return "RSVP'd to your event"
        case "EVENT_INVITE": return "posted a new event"
        default: return "sent you a notification"
        }
    }
}
