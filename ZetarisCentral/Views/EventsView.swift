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

    func createEvent(title: String, startAt: String, location: String, description: String) async -> String? {
        struct Body: Encodable { let title: String; let startAt: String; let location: String?; let description: String? }
        struct Res: Decodable { let id: String }
        if let res: Res = try? await APIClient.shared.post("/events", body: Body(
            title: title, startAt: startAt,
            location: location.isEmpty ? nil : location,
            description: description.isEmpty ? nil : description
        )) {
            await load()
            return res.id
        }
        return nil
    }
}

struct EventsView: View {
    @StateObject private var model = EventsViewModel()
    @State private var showNew = false

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Lucide("plus") }
                }
            }
            .sheet(isPresented: $showNew) { NewEventSheet(model: model) }
            .task { await model.load() }
        }
    }
}

private struct NewEventSheet: View {
    @ObservedObject var model: EventsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                DatePicker("Starts", selection: $date)
                TextField("Location (optional)", text: $location)
                TextField("Description (optional)", text: $description, axis: .vertical).lineLimit(2...5)
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let f = ISO8601DateFormatter()
                            f.formatOptions = [.withInternetDateTime]
                            if await model.createEvent(title: title, startAt: f.string(from: date), location: location, description: description) != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
