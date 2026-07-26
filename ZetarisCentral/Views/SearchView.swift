import SwiftUI

struct PersonLite: Codable, Identifiable {
    let id: String
    let name: String
    let username: String?
    let title: String?
    let avatarUrl: String?
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var posts: [Post] = []
    @Published var people: [PersonLite] = []
    @Published var searching = false

    func run() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { posts = []; people = []; return }
        searching = true
        struct Res: Codable { let posts: [Post]; let people: [PersonLite] }
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        if let res: Res = try? await APIClient.shared.get("/search?q=\(encoded)") {
            posts = res.posts
            people = res.people
        }
        searching = false
    }
}

struct SearchView: View {
    @StateObject private var model = SearchViewModel()

    var body: some View {
        List {
            if !model.people.isEmpty {
                Section("People") {
                    ForEach(model.people) { person in
                        NavigationLink(value: AppRoute.profile(person.id)) {
                            HStack {
                                AvatarView(name: person.name, url: person.avatarUrl, size: 36)
                                VStack(alignment: .leading) {
                                    Text(person.name).font(.subheadline.weight(.semibold))
                                    if let title = person.title { Text(title).font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                }
            }
            if !model.posts.isEmpty {
                Section("Posts") {
                    ForEach(model.posts) { post in
                        NavigationLink(value: AppRoute.post(post.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.author.name).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(post.content).lineLimit(2)
                            }
                        }
                    }
                }
            }
            if !model.searching && !model.query.isEmpty && model.posts.isEmpty && model.people.isEmpty {
                Text("No results.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, prompt: "Search people and posts")
        .onSubmit(of: .search) { Task { await model.run() } }
        .onChange(of: model.query) { q in
            if q.isEmpty { model.posts = []; model.people = [] }
        }
        .onAppear {
            let seed = TabRouter.shared.seedQuery
            if !seed.isEmpty { TabRouter.shared.seedQuery = ""; model.query = seed; Task { await model.run() } }
        }
    }
}
