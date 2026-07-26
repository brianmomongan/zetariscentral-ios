import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    let userId: String
    @Published var profile: Profile?
    @Published var posts: [Post] = []
    @Published var isLoading = true
    @Published var working = false
    @Published var errorMessage: String?

    init(userId: String) { self.userId = userId }

    func load() async {
        do {
            let res: ProfileResponse = try await APIClient.shared.get("/people/\(userId)")
            profile = res.profile
            posts = res.posts
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load this profile."
        }
        isLoading = false
    }

    func toggleFollow() async {
        working = true
        let _: FollowResponse? = try? await APIClient.shared.post("/people/\(userId)/follow")
        await load()
        working = false
    }

    func startDM() async -> String? {
        struct Body: Encodable { let userId: String }
        struct Res: Decodable { let conversationId: String }
        if let res: Res = try? await APIClient.shared.post("/conversations", body: Body(userId: userId)) {
            return res.conversationId
        }
        return nil
    }
}

struct ProfileView: View {
    @StateObject private var model: ProfileViewModel
    @State private var openConvo: IdentifiedString?

    init(userId: String) {
        _model = StateObject(wrappedValue: ProfileViewModel(userId: userId))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if let profile = model.profile {
                List {
                    Section {
                        ProfileHeader(profile: profile, model: model, onMessage: {
                            Task { if let id = await model.startDM() { openConvo = IdentifiedString(value: id) } }
                        })
                            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 12, trailing: 16))
                    }
                    Section("Posts") {
                        if model.posts.isEmpty {
                            Text("No posts yet.").font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(model.posts) { post in
                                NavigationLink(value: AppRoute.post(post.id)) {
                                    PostRow(post: post)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await model.load() }
            } else {
                ContentUnavailableViewCompat(title: "Unavailable", message: model.errorMessage ?? "This profile can't be shown.")
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle(model.profile?.name ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $openConvo) { convo in
            NavigationStack { ConversationView(conversationId: convo.value) }
        }
        .task { await model.load() }
    }
}

private struct ProfileHeader: View {
    let profile: Profile
    @ObservedObject var model: ProfileViewModel
    let onMessage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                AvatarView(name: profile.name, url: profile.avatarUrl, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).font(.title3.weight(.bold))
                    if let title = profile.title { Text(title).font(.subheadline).foregroundStyle(.secondary) }
                    if let username = profile.username { Text("@\(username)").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio).font(.subheadline)
            }

            let facts = [profile.department, profile.team, profile.location].compactMap { $0 }.filter { !$0.isEmpty }
            if !facts.isEmpty {
                Text(facts.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                stat(profile.postCount, "Posts")
                NavigationLink(value: AppRoute.followers(profile.id)) { stat(profile.followerCount, "Followers") }.buttonStyle(.plain)
                NavigationLink(value: AppRoute.following(profile.id)) { stat(profile.followingCount, "Following") }.buttonStyle(.plain)
            }

            if !profile.isMe {
                HStack(spacing: 10) {
                    if profile.isFollowing {
                        Button { Task { await model.toggleFollow() } } label: { Text("Following").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered).disabled(model.working)
                    } else {
                        Button { Task { await model.toggleFollow() } } label: { Text("Follow").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).disabled(model.working)
                    }
                    Button { onMessage() } label: { Text("Message").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func stat(_ count: Int, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)").font(.subheadline.weight(.semibold))
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
