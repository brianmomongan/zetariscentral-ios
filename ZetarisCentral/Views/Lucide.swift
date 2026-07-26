import SwiftUI

/// Lucide icons (the same icon set the web and Android apps use), bundled as
/// template vector assets in Assets.xcassets. Use these instead of SF Symbols
/// so the three clients look identical.
struct Lucide: View {
    let name: String
    var size: CGFloat

    init(_ name: String, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("lucide-\(name)")
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

extension Image {
    /// A Lucide asset image rendered as a tintable template (for `.tabItem`
    /// labels and other spots that need an `Image`, not a view).
    init(lucide name: String) {
        self = Image("lucide-\(name)").renderingMode(.template)
    }
}
