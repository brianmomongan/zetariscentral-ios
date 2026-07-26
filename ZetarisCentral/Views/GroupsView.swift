import SwiftUI

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published var groups: [GroupSummary] = []
    @Published var isLoading = true
    @Published var showCreate = false
    @Published var newName = ""

    func load() async {
        struct Res: Codable { let groups: [GroupSummary] }
        if let res: Res = try? await APIClient.shared.get("/groups") { groups = res.groups }
        isLoading = false
    }

    func create() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        struct Body: Codable { let name: String }
        let _: EmptyResponse? = try? await APIClient.shared.post("/groups", body: Body(name: name))
        newName = ""
        showCreate = false
        await load()
    }
}

struct GroupsView: View {
    @StateObject private var model = GroupsViewModel()

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
            } else if model.groups.isEmpty {
                ContentUnavailableViewCompat(title: "No groups", message: "Create a group to share with a named set of people.")
            } else {
                List(model.groups) { group in
                    NavigationLink(value: AppRoute.group(group.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name).font(.subheadline.weight(.semibold))
                            Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Groups")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.showCreate = true } label: { Lucide("plus") }
            }
        }
        .alert("New group", isPresented: $model.showCreate) {
            TextField("Group name", text: $model.newName)
            Button("Create") { Task { await model.create() } }
            Button("Cancel", role: .cancel) {}
        }
        .task { await model.load() }
    }
}

@MainActor
final class GroupDetailViewModel: ObservableObject {
    let groupId: String
    @Published var group: GroupDetail?
    @Published var isLoading = true
    @Published var addHandle = ""

    init(groupId: String) { self.groupId = groupId }

    func load() async {
        struct Res: Codable { let group: GroupDetail }
        if let res: Res = try? await APIClient.shared.get("/groups/\(groupId)") { group = res.group }
        isLoading = false
    }

    func addMember() async {
        let handle = addHandle.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        guard !handle.isEmpty else { return }
        struct Body: Codable { let username: String }
        let _: EmptyResponse? = try? await APIClient.shared.post("/groups/\(groupId)/members", body: Body(username: handle))
        addHandle = ""
        await load()
    }

    func remove(_ userId: String) async {
        let _: EmptyResponse? = try? await APIClient.shared.delete("/groups/\(groupId)/members?userId=\(userId)")
        await load()
    }

    func leave() async -> Bool {
        do { let _: EmptyResponse = try await APIClient.shared.post("/groups/\(groupId)/leave"); return true }
        catch { return false }
    }

    func deleteGroup() async -> Bool {
        do { let _: EmptyResponse = try await APIClient.shared.delete("/groups/\(groupId)"); return true }
        catch { return false }
    }
}

struct GroupDetailView: View {
    @StateObject private var model: GroupDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLeave = false
    @State private var showDelete = false

    init(groupId: String) {
        _model = StateObject(wrappedValue: GroupDetailViewModel(groupId: groupId))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if let group = model.group {
                List {
                    if let description = group.description, !description.isEmpty {
                        Section { Text(description) }
                    }
                    if group.isOwner {
                        Section("Add member") {
                            HStack {
                                TextField("@username", text: $model.addHandle)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                Button("Add") { Task { await model.addMember() } }
                                    .disabled(model.addHandle.isEmpty)
                            }
                        }
                    }
                    Section("Members") {
                        ForEach(group.members) { member in
                            NavigationLink(value: AppRoute.profile(member.id)) {
                                HStack {
                                    AvatarView(name: member.name, url: member.avatarUrl, size: 32)
                                    Text(member.name)
                                    if member.isOwner {
                                        Text("Owner").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions {
                                if group.isOwner && !member.isOwner {
                                    Button(role: .destructive) { Task { await model.remove(member.id) } } label: { Label { Text("Remove") } icon: { Lucide("circle-minus", size: 16) } }
                                }
                            }
                        }
                    }
                    Section {
                        if group.isOwner {
                            Button("Delete group", role: .destructive) { showDelete = true }
                        } else {
                            Button("Leave group", role: .destructive) { showLeave = true }
                        }
                    }
                }
            } else {
                ContentUnavailableViewCompat(title: "Unavailable", message: "This group can't be shown.").frame(maxHeight: .infinity)
            }
        }
        .navigationTitle(model.group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Leave group?", isPresented: $showLeave) {
            Button("Leave", role: .destructive) { Task { if await model.leave() { dismiss() } } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete group?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { Task { if await model.deleteGroup() { dismiss() } } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This can't be undone.") }
        .task { await model.load() }
    }
}
