import SwiftUI
import QuickLook

/// Downloads a file (with the auth token) to a temp path, then previews it with
/// QuickLook — which natively handles images, video, audio, PDF, text/code, etc.
@MainActor
final class FilePreviewLoader: ObservableObject {
    @Published var localURL: URL?
    @Published var failed = false

    func load(fileId: String, name: String) async {
        let remote = Config.fileURL(fileId)
        do {
            let (data, resp) = try await URLSession.shared.data(from: remote)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { failed = true; return }
            let safe = name.isEmpty ? "file" : name.replacingOccurrences(of: "/", with: "_")
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(safe)
            try? FileManager.default.removeItem(at: tmp)
            try data.write(to: tmp)
            localURL = tmp
        } catch {
            failed = true
        }
    }
}

struct FileViewerSheet: View {
    let fileId: String
    let name: String
    @StateObject private var loader = FilePreviewLoader()
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let url = loader.localURL {
                    QuickLookPreview(url: url).ignoresSafeArea(edges: .bottom)
                } else if loader.failed {
                    VStack(spacing: 12) {
                        ContentUnavailableViewCompat(title: "Couldn't preview", message: "Open it externally instead.")
                        Button("Open externally") { openURL(Config.fileURL(fileId)) }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Button { openURL(Config.fileURL(fileId)) } label: { Image(systemName: "arrow.up.forward.app") }
                }
            }
            .task { await loader.load(fileId: fileId, name: name) }
        }
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

/// Identifiable wrapper so a file can drive a `.sheet(item:)`.
struct FileRef: Identifiable {
    let id: String
    let name: String
}
