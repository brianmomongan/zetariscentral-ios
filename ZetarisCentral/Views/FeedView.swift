import SwiftUI
import PhotosUI
import UIKit

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var groups: [GroupSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filter = "foryou"

    func load() async {
        isLoading = posts.isEmpty
        errorMessage = nil
        do {
            let path = filter == "following" ? "/feed?filter=following" : "/feed"
            let res: FeedResponse = try await APIClient.shared.get(path)
            posts = res.posts
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load the feed."
        }
        isLoading = false
        if let res: GroupsResponse = try? await APIClient.shared.get("/groups") { groups = res.groups }
    }

    func createPost(_ content: String, visibility: String, groupId: String?, peopleUsernames: [String], media: [MediaRef], isAnnouncement: Bool) async -> Bool {
        struct Body: Codable { let content: String; let visibility: String; let groupId: String?; let peopleUsernames: [String]; let media: [MediaRef]; let isAnnouncement: Bool }
        do {
            let _: CreatePostResponse = try await APIClient.shared.post("/posts", body: Body(content: content, visibility: visibility, groupId: groupId, peopleUsernames: peopleUsernames, media: media, isAnnouncement: isAnnouncement))
            await load()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't post."
            return false
        }
    }
}

struct FeedView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var model = FeedViewModel()
    @State private var showComposer = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Feed", selection: $model.filter) {
                    Text("For you").tag("foryou")
                    Text("Following").tag("following")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.vertical, 6)
                .onChange(of: model.filter) { _ in Task { model.posts = []; await model.load() } }

                Group {
                    if model.isLoading {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = model.errorMessage, model.posts.isEmpty {
                        ContentUnavailableViewCompat(title: "Couldn't load", message: error)
                    } else if model.posts.isEmpty {
                        EmptyStateView(title: model.filter == "following" ? "No posts from people you follow." : "No posts yet.",
                                       subtitle: model.filter == "following" ? "Follow people to see their posts here." : "Tap the pencil to share something.")
                    } else {
                        List(model.posts) { post in
                            NavigationLink(value: AppRoute.post(post.id)) {
                                PostRow(post: post)
                            }
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .refreshable { await model.load() }
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let id = auth.currentUser?.id {
                            Button { path.append(AppRoute.profile(id)) } label: { Label { Text("My profile") } icon: { Lucide("user", size: 16) } }
                        }
                        Button { path.append(AppRoute.search) } label: { Label { Text("Search") } icon: { Lucide("search", size: 16) } }
                        Button { path.append(AppRoute.news) } label: { Label { Text("News") } icon: { Lucide("newspaper", size: 16) } }
                        Button { path.append(AppRoute.files) } label: { Label { Text("Files") } icon: { Lucide("folder-closed", size: 16) } }
                        Button { path.append(AppRoute.saved) } label: { Label { Text("Saved") } icon: { Lucide("bookmark", size: 16) } }
                        Button { path.append(AppRoute.directory) } label: { Label { Text("People") } icon: { Lucide("users", size: 16) } }
                        Button { path.append(AppRoute.groups) } label: { Label { Text("Groups") } icon: { Lucide("users-round", size: 16) } }
                        Button { path.append(AppRoute.settings) } label: { Label { Text("Settings") } icon: { Lucide("settings", size: 16) } }
                    } label: {
                        Lucide("menu")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showComposer = true } label: { Lucide("square-pen") }
                }
            }
            .sheet(isPresented: $showComposer) {
                ComposerView(groups: model.groups, isAdmin: auth.currentUser?.role == "ADMIN") { content, visibility, groupId, people, media, announce in
                    let ok = await model.createPost(content, visibility: visibility, groupId: groupId, peopleUsernames: people, media: media, isAnnouncement: announce)
                    if ok { showComposer = false }
                }
            }
            .task { await model.load() }
        }
        .handlesRouteLinks($path)
    }
}

private struct ComposerView: View {
    let groups: [GroupSummary]
    var isAdmin: Bool = false
    let onPost: (_ content: String, _ visibility: String, _ groupId: String?, _ people: [String], _ media: [MediaRef], _ isAnnouncement: Bool) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var audience = "COMPANY" // COMPANY | PRIVATE | PEOPLE | group:<id>
    @State private var announce = false
    @State private var posting = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var uploaded: [MediaRef] = []
    @State private var uploading = false
    // Specific-people picker
    @State private var selectedPeople: [PersonRef] = []
    @State private var peopleQuery = ""
    @State private var peopleResults: [PersonRef] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Menu {
                        Button { audience = "COMPANY" } label: { Label { Text("Everyone") } icon: { Lucide("globe", size: 16) } }
                        Button { audience = "PRIVATE" } label: { Label { Text("Only me") } icon: { Lucide("lock", size: 16) } }
                        Button { audience = "PEOPLE" } label: { Label { Text("Specific people") } icon: { Lucide("circle-user", size: 16) } }
                        if !groups.isEmpty {
                            Divider()
                            ForEach(groups) { group in
                                Button { audience = "group:\(group.id)" } label: { Label { Text(group.name) } icon: { Lucide("users-round", size: 16) } }
                            }
                        }
                    } label: {
                        Label(audienceLabel, systemImage: audienceIcon).font(.subheadline)
                    }
                    Spacer()
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 4, matching: .images) {
                        Lucide("image")
                    }
                }
                .padding(.horizontal).padding(.top, 8)

                if audience == "PEOPLE" { peoplePicker }

                if isAdmin && audience == "COMPANY" {
                    Toggle("📣 Post as announcement", isOn: $announce).padding(.horizontal).padding(.top, 4)
                }

                if uploading || !uploaded.isEmpty {
                    HStack {
                        if uploading { ProgressView() }
                        if !uploaded.isEmpty { Text("\(uploaded.count) photo\(uploaded.count == 1 ? "" : "s") attached").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                    }
                    .padding(.horizontal).padding(.top, 4)
                }

                TextEditor(text: $text).padding(8)
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: pickerItems) { items in
                Task { await upload(items) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        posting = true
                        let visibility = audience == "PRIVATE" ? "PRIVATE"
                            : audience == "PEOPLE" ? "PEOPLE"
                            : audience.hasPrefix("group:") ? "GROUP" : "COMPANY"
                        let groupId = audience.hasPrefix("group:") ? String(audience.dropFirst(6)) : nil
                        let people = audience == "PEOPLE" ? selectedPeople.compactMap { $0.username } : []
                        Task { await onPost(text, visibility, groupId, people, uploaded, isAdmin && audience == "COMPANY" && announce); posting = false }
                    }
                    .disabled((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && uploaded.isEmpty) || posting || uploading)
                }
            }
        }
    }

    private func upload(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        uploading = true
        uploaded = []
        for item in items {
            // Re-encode to JPEG so HEIC photos display everywhere.
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.85) {
                if let ref = try? await APIClient.shared.uploadMedia(jpeg, filename: "photo.jpg", mimeType: "image/jpeg") {
                    uploaded.append(ref)
                }
            }
        }
        uploading = false
    }

    private var audienceLabel: String {
        if audience == "PRIVATE" { return "Only me" }
        if audience == "PEOPLE" { return selectedPeople.isEmpty ? "Specific people" : "\(selectedPeople.count) people" }
        if audience.hasPrefix("group:"), let g = groups.first(where: { "group:\($0.id)" == audience }) { return g.name }
        return "Everyone"
    }
    private var audienceIcon: String {
        if audience == "PRIVATE" { return "lock" }
        if audience == "PEOPLE" { return "person.crop.circle" }
        if audience.hasPrefix("group:") { return "person.2" }
        return "globe"
    }

    private var peoplePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !selectedPeople.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedPeople) { person in
                            HStack(spacing: 4) {
                                Text(person.name).font(.caption)
                                Button { selectedPeople.removeAll { $0.id == person.id } } label: {
                                    Lucide("x").foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
            TextField("Search people to add", text: $peopleQuery)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .onChange(of: peopleQuery) { q in Task { await searchPeople(q) } }
            ForEach(peopleResults.prefix(4)) { person in
                Button {
                    if !selectedPeople.contains(where: { $0.id == person.id }) { selectedPeople.append(person) }
                    peopleQuery = ""
                    peopleResults = []
                } label: {
                    HStack(spacing: 8) {
                        AvatarView(name: person.name, url: person.avatarUrl, size: 28)
                        Text(person.name).font(.subheadline)
                        Spacer()
                        Lucide("circle-plus").foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal).padding(.top, 6)
    }

    private func searchPeople(_ q: String) async {
        let query = q.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { peopleResults = []; return }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let res: PeopleResponse = try? await APIClient.shared.get("/people?q=\(encoded)") {
            peopleResults = res.people.filter { p in !selectedPeople.contains(where: { $0.id == p.id }) }
        }
    }
}

/// Small back-compat helper so the app builds on iOS 16 (ContentUnavailableView
/// is iOS 17+).
struct ContentUnavailableViewCompat: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Lucide("triangle-alert").font(.largeTitle).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}
