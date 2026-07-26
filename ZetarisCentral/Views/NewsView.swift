import SwiftUI

@MainActor
final class NewsViewModel: ObservableObject {
    @Published var topics: [NewsTopic] = []
    @Published var articles: [Article] = []
    @Published var isLoading = true
    @Published var showAdd = false
    @Published var newTopic = ""

    func load() async {
        if let res: NewsResponse = try? await APIClient.shared.get("/news") {
            topics = res.topics
            articles = res.articles
        }
        isLoading = false
    }

    func addTopic() async {
        let q = newTopic.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        struct Body: Codable { let query: String }
        let _: EmptyResponse? = try? await APIClient.shared.post("/news", body: Body(query: q))
        newTopic = ""
        showAdd = false
        await load()
    }

    func removeTopic(_ id: String) async {
        let _: EmptyResponse? = try? await APIClient.shared.delete("/news/\(id)")
        await load()
    }

    func share(_ note: String, link: String) async {
        let content = [note.trimmingCharacters(in: .whitespaces), link].filter { !$0.isEmpty }.joined(separator: "\n")
        struct Body: Encodable { let content: String }
        let _: CreatePostResponse? = try? await APIClient.shared.post("/posts", body: Body(content: content))
    }
}

struct NewsView: View {
    @StateObject private var model = NewsViewModel()
    @State private var sharing: Article?
    @State private var shareNote = ""

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
            } else {
                List {
                    if !model.topics.isEmpty {
                        Section("Your topics") {
                            ForEach(model.topics) { topic in
                                Text(topic.query)
                                    .swipeActions {
                                        Button("Remove", role: .destructive) { Task { await model.removeTopic(topic.id) } }
                                    }
                            }
                        }
                    }
                    Section("Headlines") {
                        if model.articles.isEmpty {
                            Text("Add a topic to see headlines.").foregroundStyle(.secondary)
                        } else {
                            ForEach(model.articles) { article in
                                Link(destination: URL(string: article.link) ?? URL(string: "https://news.google.com")!) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            if let source = article.source { Text(source).font(.caption).foregroundStyle(.secondary) }
                                            Text(article.publishedAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Text(article.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    }
                                }
                                .swipeActions {
                                    Button { sharing = article } label: { Label { Text("Share") } icon: { Lucide("share-2", size: 16) } }.tint(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("News")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.showAdd = true } label: { Lucide("plus") }
            }
        }
        .alert("Follow a topic", isPresented: $model.showAdd) {
            TextField("e.g. Artificial Intelligence", text: $model.newTopic)
            Button("Follow") { Task { await model.addTopic() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Share to feed", isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
            TextField("Add a note (optional)", text: $shareNote)
            Button("Share") { if let a = sharing { Task { await model.share(shareNote, link: a.link); shareNote = ""; sharing = nil } } }
            Button("Cancel", role: .cancel) { sharing = nil }
        }
        .task { await model.load() }
    }
}
