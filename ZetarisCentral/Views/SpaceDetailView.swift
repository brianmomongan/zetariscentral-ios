import SwiftUI

@MainActor
final class SpaceDetailViewModel: ObservableObject {
    let slug: String
    @Published var data: SpaceDetailResponse?
    @Published var isLoading = true
    @Published var working = false
    @Published var errorMessage: String?

    init(slug: String) { self.slug = slug }

    func load() async {
        do {
            data = try await APIClient.shared.get("/spaces/\(slug)")
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load this space."
        }
        isLoading = false
    }

    func join() async {
        working = true
        let _: EmptyResponse? = try? await APIClient.shared.post("/spaces/\(slug)/join")
        await load()
        working = false
    }

    func leave() async {
        working = true
        let _: EmptyResponse? = try? await APIClient.shared.post("/spaces/\(slug)/leave")
        await load()
        working = false
    }

    func postToSpace(_ content: String) async {
        guard let id = data?.space.id else { return }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        struct Body: Encodable { let content: String; let spaceId: String }
        let _: CreatePostResponse? = try? await APIClient.shared.post("/posts", body: Body(content: text, spaceId: id))
        await load()
    }
}

struct SpaceDetailView: View {
    @StateObject private var model: SpaceDetailViewModel
    @State private var composing = false

    init(slug: String) {
        _model = StateObject(wrappedValue: SpaceDetailViewModel(slug: slug))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if let data = model.data {
                List {
                    Section {
                        SpaceHeader(space: data.space, members: data.members, model: model)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                    if !data.events.isEmpty {
                        Section("Upcoming events") {
                            ForEach(data.events) { event in
                                NavigationLink(value: AppRoute.event(event.id)) {
                                    EventRow(event: event)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    Section("Posts") {
                        if data.posts.isEmpty {
                            Text("No posts in this space yet.").font(.subheadline).foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(data.posts) { post in
                                ZStack {
                                    NavigationLink(value: AppRoute.post(post.id)) { EmptyView() }.opacity(0)
                                    PostRow(post: post).postCard(announcement: post.isAnnouncement)
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Theme.sunken)
                .refreshable { await model.load() }
            } else {
                ContentUnavailableViewCompat(title: "Unavailable", message: model.errorMessage ?? "This space can't be shown.")
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle(model.data?.space.name ?? "Space")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.data?.space.canPost == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { composing = true } label: { Lucide("square-pen") }
                }
            }
        }
        .sheet(isPresented: $composing) {
            SpaceComposerSheet { text in
                Task { await model.postToSpace(text); composing = false }
            }
        }
        .task { await model.load() }
    }
}

private struct SpaceComposerSheet: View {
    let onPost: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text).padding(8)
                .navigationTitle("Post to space")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Post") { onPost(text) }
                            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
        }
    }
}

private struct SpaceHeader: View {
    let space: SpaceDetail
    let members: [SpaceMemberView]
    @ObservedObject var model: SpaceDetailViewModel
    @State private var confirmLeave = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label { Text(space.visibility == "PRIVATE" ? "Private" : "Public") }
                        icon: { Lucide(space.visibility == "PRIVATE" ? "lock" : "hash", size: 13) }
                        .font(.caption).foregroundStyle(.secondary)
                    if let description = space.description, !description.isEmpty {
                        Text(description).font(.subheadline)
                    }
                    Text("\(space.memberCount) member\(space.memberCount == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                membershipButton
            }

            // Member avatar pile.
            HStack(spacing: -8) {
                ForEach(members.prefix(8)) { member in
                    AvatarView(name: member.name, url: member.avatarUrl, size: 30)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                if members.count > 8 {
                    Text("+\(members.count - 8)").font(.caption).foregroundStyle(.secondary).padding(.leading, 12)
                }
            }
        }
    }

    @ViewBuilder private var membershipButton: some View {
        if space.isOwner {
            Text("Owner").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        } else if space.isMember {
            Button("Leave") { confirmLeave = true }
                .buttonStyle(.bordered)
                .disabled(model.working)
                .alert("Leave \(space.name)?", isPresented: $confirmLeave) {
                    Button("Leave", role: .destructive) { Task { await model.leave() } }
                    Button("Cancel", role: .cancel) {}
                }
        } else if space.visibility == "PUBLIC" {
            Button("Join") { Task { await model.join() } }
                .buttonStyle(.borderedProminent)
                .disabled(model.working)
        }
    }
}

struct EventRow: View {
    let event: EventListItem
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(event.startAt, format: .dateTime.month(.abbreviated)).font(.caption2).foregroundStyle(.tint)
                Text(event.startAt, format: .dateTime.day()).font(.headline)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(event.startAt, format: .dateTime.weekday().hour().minute()) · \(event.counts.GOING) going")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
