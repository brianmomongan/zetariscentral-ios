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
}

struct SpacesView: View {
    @StateObject private var model = SpacesViewModel()

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
            .task { await model.load() }
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
