import SwiftUI

@MainActor
final class SpacesViewModel: ObservableObject {
    @Published var spaces: [SpaceSummary] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load() async {
        do {
            let res: SpacesResponse = try await APIClient.shared.get("/spaces")
            spaces = res.spaces
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load spaces."
        }
        isLoading = false
    }

    func createSpace(name: String, description: String, visibility: String) async {
        struct Body: Encodable { let name: String; let description: String?; let visibility: String }
        let _: EmptyResponse? = try? await APIClient.shared.post("/spaces", body: Body(
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.isEmpty ? nil : description,
            visibility: visibility
        ))
        await load()
    }
}

struct SpacesView: View {
    @StateObject private var model = SpacesViewModel()
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if model.spaces.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "No spaces",
                        message: model.errorMessage ?? "Spaces you can see will appear here."
                    )
                } else {
                    List(model.spaces) { space in
                        NavigationLink(value: AppRoute.space(space.slug)) {
                            SpaceListRow(space: space)
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle("Spaces")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: { Lucide("plus") }
                }
            }
            .sheet(isPresented: $showCreate) { NewSpaceSheet(model: model) }
            .task { await model.load() }
        }
    }
}

private struct NewSpaceSheet: View {
    @ObservedObject var model: SpacesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description (optional)", text: $description, axis: .vertical).lineLimit(2...4)
                Picker("Visibility", selection: $isPublic) {
                    Text("Public").tag(true)
                    Text("Private").tag(false)
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle("New space")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await model.createSpace(name: name, description: description, visibility: isPublic ? "PUBLIC" : "PRIVATE"); dismiss() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).count < 2)
                }
            }
        }
    }
}

private struct SpaceListRow: View {
    let space: SpaceSummary
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.tint.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: space.visibility == "PRIVATE" ? "lock.fill" : "number")
                    .foregroundStyle(.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(space.name).font(.subheadline.weight(.semibold))
                Text("\(space.memberCount) member\(space.memberCount == 1 ? "" : "s")\(space.isMember ? " · Joined" : "")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
