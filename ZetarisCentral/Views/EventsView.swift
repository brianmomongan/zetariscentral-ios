import SwiftUI

@MainActor
final class EventsViewModel: ObservableObject {
    @Published var events: [EventListItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load() async {
        do {
            let res: EventsResponse = try await APIClient.shared.get("/events")
            events = res.events
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load events."
        }
        isLoading = false
    }
}

struct EventsView: View {
    @StateObject private var model = EventsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView()
                } else if model.events.isEmpty {
                    ContentUnavailableViewCompat(
                        title: "No upcoming events",
                        message: model.errorMessage ?? "Company and team events will show up here."
                    )
                } else {
                    List(model.events) { event in
                        NavigationLink(value: AppRoute.event(event.id)) {
                            EventRow(event: event)
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(for: AppRoute.self) { destinationView(for: $0) }
                    .refreshable { await model.load() }
                }
            }
            .navigationTitle("Events")
            .task { await model.load() }
        }
    }
}
