import SwiftUI

private struct EditableUser: Codable {
    let name: String
    let title: String?
    let bio: String?
    let department: String?
    let team: String?
    let location: String?
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var name = ""
    @Published var title = ""
    @Published var bio = ""
    @Published var department = ""
    @Published var team = ""
    @Published var location = ""
    @Published var isLoading = true
    @Published var saving = false
    @Published var saved = false

    func load() async {
        struct Res: Codable { let user: EditableUser }
        if let res: Res = try? await APIClient.shared.get("/me") {
            name = res.user.name
            title = res.user.title ?? ""
            bio = res.user.bio ?? ""
            department = res.user.department ?? ""
            team = res.user.team ?? ""
            location = res.user.location ?? ""
        }
        isLoading = false
    }

    func save() async {
        saving = true
        saved = false
        struct Body: Codable {
            let name: String; let title: String; let bio: String
            let department: String; let team: String; let location: String
        }
        let _: EmptyResponse? = try? await APIClient.shared.patch("/me", body: Body(name: name, title: title, bio: bio, department: department, team: team, location: location))
        saving = false
        saved = true
    }
}

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var model = SettingsViewModel()

    var body: some View {
        Form {
            if model.isLoading {
                ProgressView()
            } else {
                Section("Profile") {
                    LabeledField("Name", text: $model.name)
                    LabeledField("Title", text: $model.title)
                    LabeledField("Department", text: $model.department)
                    LabeledField("Team", text: $model.team)
                    LabeledField("Location", text: $model.location)
                }
                Section("Bio") {
                    TextField("About you", text: $model.bio, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    Button {
                        Task { await model.save(); await auth.refreshMe() }
                    } label: {
                        if model.saving { ProgressView() } else { Text(model.saved ? "Saved ✓" : "Save changes") }
                    }
                    .disabled(model.saving || model.name.isEmpty)
                }
                Section {
                    Button("Sign out", role: .destructive) { auth.logout() }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }
}

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    init(_ label: String, text: Binding<String>) { self.label = label; self._text = text }
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 96, alignment: .leading)
            TextField(label, text: $text)
        }
    }
}
