import SwiftUI

@MainActor
final class ConversationsViewModel: ObservableObject {
    @Published var conversations: [ConversationSummary] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load() async {
        do {
            let res: ConversationsResponse = try await APIClient.shared.get("/conversations")
            conversations = res.conversations
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load messages."
        }
        isLoading = false
    }
}

struct ConversationsView: View {
    @StateObject private var model = ConversationsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if model.conversations.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "No messages yet",
                        message: model.errorMessage ?? "Your conversations will show up here."
                    )
                } else {
                    List(model.conversations) { convo in
                        NavigationLink(value: convo.id) {
                            ConversationRow(convo: convo)
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: String.self) { id in
                        ConversationView(conversationId: id)
                    }
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle("Messages")
            .task { await model.load() }
        }
    }
}

private struct ConversationRow: View {
    let convo: ConversationSummary

    var body: some View {
        HStack(spacing: 12) {
            if convo.isGroup {
                ZStack {
                    Circle().fill(.tint.opacity(0.2)).frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill").foregroundStyle(.tint)
                }
            } else {
                AvatarView(name: convo.members.first?.name ?? convo.title,
                           url: convo.members.first?.avatarUrl,
                           size: 44)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(convo.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(convo.lastMessage ?? "No messages yet")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(convo.lastMessageAt, style: .relative)
                    .font(.caption2).foregroundStyle(.secondary)
                if convo.unread > 0 {
                    Text("\(convo.unread)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint, in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
