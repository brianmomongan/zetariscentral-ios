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

    func startDM(_ userId: String) async -> String? {
        struct Body: Encodable { let userId: String }
        struct Res: Decodable { let conversationId: String }
        if let res: Res = try? await APIClient.shared.post("/conversations", body: Body(userId: userId)) {
            return res.conversationId
        }
        return nil
    }
}

struct ConversationsView: View {
    @StateObject private var model = ConversationsViewModel()
    @State private var path = NavigationPath()
    @State private var composing = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if model.conversations.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "No messages yet",
                        message: model.errorMessage ?? "Tap the pencil to start a conversation."
                    )
                } else {
                    List(model.conversations) { convo in
                        NavigationLink(value: AppRoute.conversation(convo.id)) {
                            ConversationRow(convo: convo)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await model.load() }
                }
            }
            .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { composing = true } label: { Lucide("square-pen") }
                }
            }
            .sheet(isPresented: $composing) {
                NewMessageSheet { person in
                    Task {
                        if let id = await model.startDM(person.id) {
                            composing = false
                            path.append(AppRoute.conversation(id))
                        }
                    }
                }
            }
            .task { await model.load() }
        }
    }
}

private struct NewMessageSheet: View {
    let onPick: (PersonRef) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PersonRef] = []

    var body: some View {
        NavigationStack {
            List(results) { person in
                Button { onPick(person) } label: {
                    HStack(spacing: 10) {
                        AvatarView(name: person.name, url: person.avatarUrl, size: 32)
                        VStack(alignment: .leading) {
                            Text(person.name).font(.subheadline.weight(.semibold))
                            if let title = person.title { Text(title).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .searchable(text: $query)
            .onChange(of: query) { q in Task { await search(q) } }
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func search(_ q: String) async {
        let query = q.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { results = []; return }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let res: PeopleResponse = try? await APIClient.shared.get("/people?q=\(encoded)") { results = res.people }
    }
}

private struct ConversationRow: View {
    let convo: ConversationSummary

    var body: some View {
        HStack(spacing: 12) {
            if convo.isGroup {
                ZStack {
                    Circle().fill(.tint.opacity(0.2)).frame(width: 44, height: 44)
                    Lucide("users-round").foregroundStyle(.tint)
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
