import SwiftUI

@MainActor
final class EventDetailViewModel: ObservableObject {
    let eventId: String
    @Published var event: EventDetail?
    @Published var isLoading = true
    @Published var working = false
    @Published var errorMessage: String?

    init(eventId: String) { self.eventId = eventId }

    func load() async {
        do {
            let res: EventResponse = try await APIClient.shared.get("/events/\(eventId)")
            event = res.event
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load this event."
        }
        isLoading = false
    }

    func rsvp(_ status: String) async {
        working = true
        struct Ack: Codable { let ok: Bool }
        let _: Ack? = try? await APIClient.shared.post("/events/\(eventId)/rsvp", body: ["status": status])
        await load()
        working = false
    }
}

struct EventDetailView: View {
    @StateObject private var model: EventDetailViewModel

    init(eventId: String) {
        _model = StateObject(wrappedValue: EventDetailViewModel(eventId: eventId))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if let event = model.event {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(event.title).font(.title2.bold())
                        Label(event.startAt.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                            .font(.subheadline)
                        if let endAt = event.endAt {
                            Label("Until \(endAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let location = event.location {
                            Label(location, systemImage: "mappin.and.ellipse").font(.subheadline)
                        }
                        Label("Hosted by \(event.host.name)", systemImage: "person").font(.subheadline).foregroundStyle(.secondary)

                        if let description = event.description, !description.isEmpty {
                            Text(description).font(.body)
                        }

                        Divider()

                        if event.canRsvp {
                            Text("Will you go?").font(.headline)
                            HStack(spacing: 10) {
                                rsvpButton("GOING", "Going", current: event.myStatus)
                                rsvpButton("MAYBE", "Maybe", current: event.myStatus)
                                rsvpButton("NO", "Can't", current: event.myStatus)
                            }
                        } else if let space = event.space {
                            Text("Join \(space.name) to RSVP.").font(.subheadline).foregroundStyle(.secondary)
                        }

                        Divider()

                        Text("\(event.counts.GOING) going · \(event.counts.MAYBE) maybe")
                            .font(.subheadline).foregroundStyle(.secondary)
                        AttendeePile(attendees: event.attendees.GOING)
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableViewCompat(title: "Unavailable", message: model.errorMessage ?? "This event can't be shown.")
                    .frame(maxHeight: .infinity)
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    private func rsvpButton(_ status: String, _ label: String, current: String?) -> some View {
        let selected = current == status
        return Button {
            Task { await model.rsvp(status) }
        } label: {
            Text(label).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(selected ? .accentColor : .secondary)
        .disabled(model.working)
    }
}

private struct AttendeePile: View {
    let attendees: [Member]
    var body: some View {
        if attendees.isEmpty {
            Text("No one's RSVP'd yet.").font(.subheadline).foregroundStyle(.secondary)
        } else {
            HStack(spacing: -8) {
                ForEach(attendees.prefix(10)) { member in
                    AvatarView(name: member.name, url: member.avatarUrl, size: 32)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                if attendees.count > 10 {
                    Text("+\(attendees.count - 10)").font(.caption).foregroundStyle(.secondary).padding(.leading, 12)
                }
            }
        }
    }
}
