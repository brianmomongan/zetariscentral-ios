import SwiftUI
import PhotosUI
import UIKit

extension Date {
    var iso8601Millis: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: self)
    }
}

private func sameDay(_ a: Date, _ b: Date) -> Bool { Calendar.current.isDate(a, inSameDayAs: b) }
private func dayLabel(_ d: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "Today" }
    if cal.isDateInYesterday(d) { return "Yesterday" }
    let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
}
private func clockTime(_ d: Date) -> String {
    let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f.string(from: d)
}

@MainActor
final class ConversationViewModel: ObservableObject {
    let conversationId: String
    @Published var detail: ConversationDetail?
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = true
    @Published var draft = ""
    @Published var pendingImage: MediaRef?
    @Published var typingNames: [String] = []
    @Published var errorMessage: String?
    private var lastPing = Date.distantPast

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
        if let res: MessagesResponse = try? await APIClient.shared.get("/conversations/\(conversationId)/messages?since=\(since)") {
            let known = Set(messages.map(\.id))
            let fresh = res.messages.filter { !known.contains($0.id) }
            if !fresh.isEmpty { messages.append(contentsOf: fresh) }
        }
        if let res: TypingResponse = try? await APIClient.shared.get("/conversations/\(conversationId)/typing") {
            typingNames = res.typing
        }
    }

    func onTyping() {
        let now = Date()
        guard now.timeIntervalSince(lastPing) > 2.5 else { return }
        lastPing = now
        Task { let _: EmptyResponse? = try? await APIClient.shared.post("/conversations/\(conversationId)/typing") }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pendingImage?.url
        guard !text.isEmpty || image != nil else { return }
        draft = ""; pendingImage = nil
        struct Body: Encodable { let body: String; let imageUrl: String? }
        do {
            let _: EmptyResponse = try await APIClient.shared.post("/conversations/\(conversationId)/messages", body: Body(body: text, imageUrl: image))
            await poll()
        } catch {
            draft = text
            errorMessage = "Couldn't send. Try again."
        }
    }

    func attach(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85),
              let ref = try? await APIClient.shared.uploadMedia(jpeg, filename: "photo.jpg", mimeType: "image/jpeg")
        else { return }
        pendingImage = ref
    }

    // MARK: Group management
    func rename(_ name: String) async {
        let _: EmptyResponse? = try? await APIClient.shared.patch("/conversations/\(conversationId)", body: ["name": name])
        await load()
    }
    func addMembers(_ ids: [String]) async {
        struct Body: Encodable { let userIds: [String] }
        let _: EmptyResponse? = try? await APIClient.shared.post("/conversations/\(conversationId)/members", body: Body(userIds: ids))
        await load()
    }
    func removeMember(_ id: String) async {
        let _: EmptyResponse? = try? await APIClient.shared.delete("/conversations/\(conversationId)/members?userId=\(id)")
        await load()
    }
    func leave(_ myId: String) async -> Bool {
        do { let _: EmptyResponse = try await APIClient.shared.delete("/conversations/\(conversationId)/members?userId=\(myId)"); return true }
        catch { return false }
    }
}

struct ConversationView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ConversationViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var managing = false
    @State private var lightboxURL: URL?

    init(conversationId: String) {
        _model = StateObject(wrappedValue: ConversationViewModel(conversationId: conversationId))
    }

    private var myId: String { auth.currentUser?.id ?? "" }
    private var isGroup: Bool { model.detail?.isGroup ?? false }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if model.messages.isEmpty {
                EmptyStateView(title: "No messages yet.", subtitle: "Say hello 👋").frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(model.messages.enumerated()), id: \.element.id) { i, message in
                                let prev = i > 0 ? model.messages[i - 1] : nil
                                let next = i < model.messages.count - 1 ? model.messages[i + 1] : nil
                                let newDay = prev == nil || !sameDay(prev!.createdAt, message.createdAt)
                                let firstInGroup = newDay || prev?.senderId != message.senderId
                                let lastInGroup = next == nil || next?.senderId != message.senderId || !sameDay(next!.createdAt, message.createdAt)
                                let mine = message.senderId == myId

                                if newDay { DaySeparator(label: dayLabel(message.createdAt)) }
                                MessageBubble(message: message, isMine: mine, isGroup: isGroup, firstInGroup: firstInGroup, lastInGroup: lastInGroup, onOpenImage: { lightboxURL = $0 })
                                    .id(message.id)
                                if mine && i == model.messages.count - 1, let read = model.detail?.readReceipt, read >= message.createdAt {
                                    Text("Seen").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 4)
                                }
                            }
                            if !model.typingNames.isEmpty {
                                Text(typingText(model.typingNames)).font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: model.messages.count) { _ in
                        if let last = model.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onAppear { if let last = model.messages.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            Composer(model: model, photoItem: $photoItem)
        }
        .navigationTitle(model.detail?.title ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isGroup {
                ToolbarItem(placement: .topBarTrailing) { Button { managing = true } label: { Lucide("users-round") } }
            }
        }
        .onChange(of: photoItem) { item in Task { await model.attach(item) } }
        .sheet(isPresented: $managing) {
            if let detail = model.detail {
                ManageGroupSheet(detail: detail, myId: myId, model: model) { dismiss() }
            }
        }
        .fullScreenCover(item: Binding(get: { lightboxURL.map { IdentifiedURL(url: $0) } }, set: { lightboxURL = $0?.url })) { wrapped in
            ImageLightbox(url: wrapped.url)
        }
        .task {
            await model.load()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await model.poll()
            }
        }
    }

    private func typingText(_ names: [String]) -> String {
        switch names.count {
        case 1: return "\(names[0]) is typing…"
        case 2: return "\(names[0]) and \(names[1]) are typing…"
        default: return "Several people are typing…"
        }
    }
}

private struct IdentifiedURL: Identifiable { let url: URL; var id: String { url.absoluteString } }

private struct DaySeparator: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.caption2).foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(Color(.secondarySystemBackground), in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let isGroup: Bool
    let firstInGroup: Bool
    let lastInGroup: Bool
    let onOpenImage: (URL) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMine { Spacer(minLength: 40) }
            if isGroup && !isMine {
                if lastInGroup { AvatarView(name: message.sender.name, url: message.sender.avatarUrl, size: 28) }
                else { Color.clear.frame(width: 28, height: 1) }
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if isGroup && !isMine && firstInGroup {
                    Text(message.sender.name).font(.caption2).foregroundStyle(.secondary)
                }
                if let img = message.imageUrl, let url = Config.mediaURL(img) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.1) }
                        .frame(width: 200, height: 200).clipShape(RoundedRectangle(cornerRadius: 16))
                        .onTapGesture { onOpenImage(url) }
                }
                if let file = message.file {
                    Label { Text(file.name) } icon: { Lucide("file-text", size: 16) }
                        .font(.subheadline).padding(10)
                        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(isMine ? .white : .primary)
                        .onTapGesture { UIApplication.shared.open(Config.fileURL(file.id)) }
                }
                if !message.body.isEmpty {
                    Text(message.body)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(isMine ? .white : .primary)
                }
                if lastInGroup {
                    Text(clockTime(message.createdAt)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !isMine { Spacer(minLength: 40) }
        }
        .padding(.top, firstInGroup ? 6 : 1)
    }

    private var bubbleColor: Color { isMine ? .accentColor : Color(.secondarySystemBackground) }
}

private let quickEmoji = ["🚀", "🎉", "👏", "🙌", "🔥", "💡", "✅", "❤️", "😄", "🙏"]

private struct Composer: View {
    @ObservedObject var model: ConversationViewModel
    @Binding var photoItem: PhotosPickerItem?

    var body: some View {
        Divider()
        if model.pendingImage != nil {
            HStack {
                Lucide("image").foregroundStyle(.secondary)
                Text("Photo attached").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { model.pendingImage = nil } label: { Lucide("x").foregroundStyle(.secondary) }
            }
            .padding(.horizontal).padding(.top, 6)
        }
        HStack(spacing: 8) {
            PhotosPicker(selection: $photoItem, matching: .images) { Lucide("image", size: 22) }
            Menu {
                ForEach(quickEmoji, id: \.self) { e in Button(e) { model.draft += e } }
            } label: { Lucide("smile", size: 22) }
            TextField("Message…", text: $model.draft, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...4)
                .onChange(of: model.draft) { _ in model.onTyping() }
            Button { Task { await model.send() } } label: { Lucide("send", size: 24) }
                .disabled(model.draft.trimmingCharacters(in: .whitespaces).isEmpty && model.pendingImage == nil)
        }
        .padding(12)
    }
}

struct ImageLightbox: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                .onTapGesture { dismiss() }
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: { Lucide("x", size: 28).foregroundStyle(.white) }.padding()
                }
                Spacer()
            }
        }
    }
}

private struct ManageGroupSheet: View {
    let detail: ConversationDetail
    let myId: String
    @ObservedObject var model: ConversationViewModel
    let onLeft: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var query = ""
    @State private var results: [PersonRef] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Group name", text: $name)
                    Button("Save name") { Task { await model.rename(name) } }.disabled(name.isEmpty)
                }
                Section("Members") {
                    ForEach(detail.members) { member in
                        HStack {
                            AvatarView(name: member.name, url: member.avatarUrl, size: 28)
                            Text(member.name)
                            Spacer()
                            Button(role: .destructive) { Task { await model.removeMember(member.id) } } label: { Lucide("circle-minus") }
                        }
                    }
                }
                Section("Add people") {
                    TextField("Search people", text: $query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onChange(of: query) { q in Task { await search(q) } }
                    ForEach(results.prefix(5)) { person in
                        Button {
                            Task { await model.addMembers([person.id]); query = ""; results = [] }
                        } label: { Label { Text("Add \(person.name)") } icon: { Lucide("circle-plus", size: 16) } }
                    }
                }
                Section {
                    Button("Leave group", role: .destructive) {
                        Task { if await model.leave(myId) { dismiss(); onLeft() } }
                    }
                }
            }
            .navigationTitle("Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { name = detail.name ?? detail.title }
        }
    }

    private func search(_ q: String) async {
        let query = q.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { results = []; return }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let res: PeopleResponse = try? await APIClient.shared.get("/people?q=\(encoded)") {
            let existing = Set(detail.members.map(\.id))
            results = res.people.filter { !existing.contains($0.id) && $0.id != myId }
        }
    }
}
