import SwiftUI
import PhotosUI
import UIKit

private struct EditableUser: Codable {
    let name: String
    let title: String?
    let bio: String?
    let department: String?
    let team: String?
    let location: String?
    let avatarUrl: String?
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var name = ""
    @Published var title = ""
    @Published var bio = ""
    @Published var department = ""
    @Published var team = ""
    @Published var location = ""
    @Published var avatarUrl: String?
    @Published var isLoading = true
    @Published var saving = false
    @Published var saved = false
    @Published var passwordMsg: String?

    struct ProfileBody: Encodable {
        let name: String; let title: String; let bio: String
        let department: String; let team: String; let location: String
        let avatarUrl: String?
    }

    private func body(avatar: String?) -> ProfileBody {
        ProfileBody(name: name, title: title, bio: bio, department: department, team: team, location: location, avatarUrl: avatar)
    }

    func load() async {
        struct Res: Codable { let user: EditableUser }
        if let res: Res = try? await APIClient.shared.get("/me") {
            name = res.user.name
            title = res.user.title ?? ""
            bio = res.user.bio ?? ""
            department = res.user.department ?? ""
            team = res.user.team ?? ""
            location = res.user.location ?? ""
            avatarUrl = res.user.avatarUrl
        }
        isLoading = false
    }

    func save() async {
        saving = true; saved = false
        let _: EmptyResponse? = try? await APIClient.shared.patch("/me", body: body(avatar: avatarUrl))
        saving = false; saved = true
    }

    func saveAvatar(_ url: String) async {
        if let _: EmptyResponse = try? await APIClient.shared.patch("/me", body: body(avatar: url)) {
            avatarUrl = url
        }
    }

    func changePassword(current: String, new: String) async -> Bool {
        passwordMsg = nil
        struct Body: Encodable { let currentPassword: String; let newPassword: String }
        do {
            let _: EmptyResponse = try await APIClient.shared.post("/me/password", body: Body(currentPassword: current, newPassword: new))
            passwordMsg = "Password changed ✓"
            return true
        } catch {
            passwordMsg = "Couldn't change password (check current password)."
            return false
        }
    }

    func deleteAccount(password: String) async -> Bool {
        struct Body: Encodable { let password: String }
        do { let _: EmptyResponse = try await APIClient.shared.delete("/me", body: Body(password: password)); return true }
        catch { return false }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var model = SettingsViewModel()
    @AppStorage("theme_mode") private var themeMode = "system"
    @State private var avatarItem: PhotosPickerItem?
    @State private var currentPw = ""
    @State private var newPw = ""
    @State private var confirmPw = ""
    @State private var deletePw = ""
    @State private var showDelete = false
    @State private var server = Config.origin

    var body: some View {
        Form {
            if model.isLoading {
                ProgressView()
            } else {
                Section {
                    HStack(spacing: 16) {
                        AvatarView(name: model.name.isEmpty ? "?" : model.name, url: model.avatarUrl, size: 64)
                        PhotosPicker("Change photo", selection: $avatarItem, matching: .images)
                    }
                }
                .onChange(of: avatarItem) { item in Task { await uploadAvatar(item) } }

                Section("Appearance") {
                    Picker("Theme", selection: $themeMode) {
                        Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

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

                Section("Change password") {
                    SecureField("Current password", text: $currentPw)
                    SecureField("New password (min 8)", text: $newPw)
                    SecureField("Confirm new password", text: $confirmPw)
                    Button("Change password") {
                        Task { if await model.changePassword(current: currentPw, new: newPw) { currentPw = ""; newPw = ""; confirmPw = "" } }
                    }
                    .disabled(currentPw.isEmpty || newPw.count < 8 || newPw != confirmPw)
                    if let msg = model.passwordMsg { Text(msg).font(.footnote).foregroundStyle(.secondary) }
                }

                Section("Server") {
                    TextField("Server URL", text: $server).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Save server & sign in again") { Config.setOrigin(server); auth.logout() }
                        .disabled(!server.hasPrefix("http"))
                }

                Section {
                    Button("Sign out", role: .destructive) { auth.logout() }
                }

                Section("Danger zone") {
                    SecureField("Password to confirm", text: $deletePw)
                    Button("Delete account", role: .destructive) { showDelete = true }
                        .disabled(deletePw.isEmpty)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete account?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { Task { if await model.deleteAccount(password: deletePw) { auth.logout() } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently deletes your account, posts, and comments.") }
        .task { await model.load() }
    }

    private func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85),
              let ref = try? await APIClient.shared.uploadMedia(jpeg, filename: "avatar.jpg", mimeType: "image/jpeg")
        else { return }
        await model.saveAvatar(ref.url)
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
