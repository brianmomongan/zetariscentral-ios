import SwiftUI

extension Date {
    /// ISO-8601 with fractional seconds, matching what the API expects for the
    /// `since` polling cursor.
    var iso8601Millis: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }
}

@MainActor
final class ConversationViewModel: ObservableObject {
    let conversationId: String
    @Published var detail: ConversationDetail?
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = true
    @Published var draft = ""
    @Published var errorMessage: String?

    init(conversationId: String) { self.conversationId = conversationId }

    func load() async {
        do {
            let res: ConversationResponse = try await APIClient.shared.get("/conversations/\(conversationId)")
            detail = res.conversation
            messages = res.conversation.messages
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't open this conversation."
        }
        isLoading = false
    }

    func poll() async {
        guard let last = messages.last else { return }
        let since = last.createdAt.iso8601Millis.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let res: MessagesResponse = try? await APIClient.shared.get("/conversations/\(conversationId)/messages?since=\(since)") else {
            return
        }
        let known = Set(messages.map(\.id))
        let fresh = res.messages.filter { !known.contains($0.id) }
        if !fresh.isEmpty { messages.append(contentsOf: fresh) }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        do {
            let _: EmptyResponse = try await APIClient.shared.post("/conversations/\(conversationId)/messages", body: ["body": text])
            await poll()
        } catch {
            draft = text // restore so the user doesn't lose it
            errorMessage = "Couldn't send. Try again."
        }
    }
}

struct ConversationView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var model: ConversationViewModel

    init(conversationId: String) {
        _model = StateObject(wrappedValue: ConversationViewModel(conversationId: conversationId))
    }

    private var myId: String { auth.currentUser?.id ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(model.messages) { message in
                                MessageBubble(message: message, isMine: message.senderId == myId, isGroup: model.detail?.isGroup ?? false)
                                    .id(message.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: model.messages.count) { _ in
                        if let last = model.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Composer(model: model)
        }
        .navigationTitle(model.detail?.title ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load()
            // Lightweight polling while the thread is open.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await model.poll()
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let isGroup: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if isGroup && !isMine {
                    Text(message.sender.name).font(.caption2).foregroundStyle(.secondary)
                }
                if let file = message.file {
                    Label(file.name, systemImage: "doc")
                        .font(.subheadline)
                        .padding(10)
                        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(isMine ? .white : .primary)
                } else if !message.body.isEmpty {
                    Text(message.body)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(isMine ? .white : .primary)
                }
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }

    private var bubbleColor: Color { isMine ? .accentColor : Color(.secondarySystemBackground) }
}

private struct Composer: View {
    @ObservedObject var model: ConversationViewModel

    var body: some View {
        Divider()
        HStack(spacing: 10) {
            TextField("Message…", text: $model.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await model.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(model.draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
    }
}
