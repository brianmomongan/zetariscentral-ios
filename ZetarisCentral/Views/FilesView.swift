import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var drive = "PERSONAL"
    @Published var stack: [Breadcrumb] = []   // folders we've descended into
    @Published var items: [FileNode] = []
    @Published var isLoading = true
    @Published var busy = false

    var currentFolder: String? { stack.last?.id }
    var canWrite: Bool { drive != "SHARED" }

    func createFolder(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        struct Body: Codable { let drive: String; let parentId: String?; let name: String }
        let _: EmptyResponse? = try? await APIClient.shared.post("/files", body: Body(drive: drive, parentId: currentFolder, name: trimmed))
        await load()
    }

    func upload(_ url: URL) async {
        busy = true
        defer { busy = false }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        try? await APIClient.shared.uploadFileToDrive(data, filename: url.lastPathComponent, mimeType: mime, drive: drive, parentId: currentFolder)
        await load()
    }

    func load() async {
        isLoading = true
        var path = "/files?drive=\(drive)"
        if let f = currentFolder { path += "&folder=\(f)" }
        if let res: FilesResponse = try? await APIClient.shared.get(path) { items = res.items }
        isLoading = false
    }

    func switchDrive(_ d: String) {
        drive = d
        stack = []
        Task { await load() }
    }

    func open(_ node: FileNode) {
        stack.append(Breadcrumb(id: node.id, name: node.name))
        Task { await load() }
    }

    func up() {
        guard !stack.isEmpty else { return }
        stack.removeLast()
        Task { await load() }
    }

    func rename(_ id: String, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let _: EmptyResponse? = try? await APIClient.shared.patch("/files/\(id)", body: ["name": trimmed])
        await load()
    }

    func delete(_ id: String) async {
        let _: EmptyResponse? = try? await APIClient.shared.delete("/files/\(id)")
        await load()
    }
}

struct FilesView: View {
    @StateObject private var model = FilesViewModel()
    @Environment(\.openURL) private var openURL
    @State private var showImporter = false
    @State private var showNewFolder = false
    @State private var folderName = ""
    @State private var fileToView: FileRef?
    @State private var renaming: FileNode?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Drive", selection: Binding(get: { model.drive }, set: { model.switchDrive($0) })) {
                Text("My Files").tag("PERSONAL")
                Text("Company").tag("COMPANY")
                Text("Shared").tag("SHARED")
            }
            .pickerStyle(.segmented)
            .padding()

            if !model.stack.isEmpty {
                HStack {
                    Button {
                        model.up()
                    } label: {
                        Label { Text(model.stack.dropLast().last?.name ?? "Back") } icon: { Lucide("chevron-left", size: 16) }
                    }
                    Spacer()
                    Text(model.stack.last?.name ?? "").font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                .padding(.horizontal)
            }

            if model.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if model.items.isEmpty {
                ContentUnavailableViewCompat(title: "Empty", message: "This folder has no items.").frame(maxHeight: .infinity)
            } else {
                List(model.items) { item in
                    Button {
                        if item.kind == "FOLDER" { model.open(item) }
                        else { fileToView = FileRef(id: item.id, name: item.name) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: item))
                                .foregroundStyle(item.kind == "FOLDER" ? Color.accentColor : .secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name).foregroundStyle(.primary)
                                if item.kind == "FILE" {
                                    Text(sizeLabel(item.size)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if item.kind == "FOLDER" { Lucide("chevron-right").font(.caption).foregroundStyle(.tertiary) }
                        }
                    }
                    .swipeActions {
                        if model.canWrite {
                            Button(role: .destructive) { Task { await model.delete(item.id) } } label: { Label { Text("Delete") } icon: { Lucide("trash-2", size: 16) } }
                            Button { renaming = item; renameText = item.name } label: { Label { Text("Rename") } icon: { Lucide("pencil", size: 16) } }.tint(.accentColor)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.canWrite {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showImporter = true } label: { Label { Text("Upload file") } icon: { Lucide("upload", size: 16) } }
                        Button { showNewFolder = true } label: { Label { Text("New folder") } icon: { Lucide("folder-plus", size: 16) } }
                    } label: {
                        Image(systemName: model.busy ? "hourglass" : "plus")
                    }
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result { Task { await model.upload(url) } }
        }
        .alert("New folder", isPresented: $showNewFolder) {
            TextField("Folder name", text: $folderName)
            Button("Create") { Task { await model.createFolder(folderName); folderName = "" } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("New name", text: $renameText)
            Button("Rename") { if let item = renaming { Task { await model.rename(item.id, to: renameText); renaming = nil } } }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .sheet(item: $fileToView) { ref in
            FileViewerSheet(fileId: ref.id, name: ref.name)
        }
        .task { await model.load() }
    }

    private func icon(for item: FileNode) -> String {
        if item.kind == "FOLDER" { return "folder.fill" }
        let m = item.mimeType ?? ""
        if m.hasPrefix("image/") { return "photo" }
        if m.hasPrefix("video/") { return "film" }
        if m == "application/pdf" { return "doc.richtext" }
        return "doc"
    }

    private func sizeLabel(_ bytes: Int?) -> String {
        guard let bytes, bytes > 0 else { return "" }
        let units = ["B", "KB", "MB", "GB"]
        var n = Double(bytes)
        var i = 0
        while n >= 1024 && i < units.count - 1 { n /= 1024; i += 1 }
        return String(format: n < 10 && i > 0 ? "%.1f %@" : "%.0f %@", n, units[i])
    }
}
