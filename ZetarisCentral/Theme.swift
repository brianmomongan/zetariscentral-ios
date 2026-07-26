import SwiftUI
import UIKit

/// The Zetaris "Team Room" accent — one sky-blue voice (see DESIGN.md), tuned
/// brighter in dark mode. Applied app-wide via `.tint(Theme.sky)`.
enum Theme {
    static let sky = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0x38 / 255.0, green: 0xBD / 255.0, blue: 0xF8 / 255.0, alpha: 1) // #38bdf8
            : UIColor(red: 0x02 / 255.0, green: 0x84 / 255.0, blue: 0xC7 / 255.0, alpha: 1) // #0284c7
    })

    static let announce = Color(red: 0xF5 / 255.0, green: 0x9E / 255.0, blue: 0x0B / 255.0)

    private static func dyn(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { t in t.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) })
    }
    private static func rgb(_ hex: UInt) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    // Card surfaces (DESIGN.md): white/#0f172a card on a slate-100/#020617 sunken page.
    static let surface = dyn(0xFFFFFF, 0x0F172A)
    static let sunken  = dyn(0xF1F5F9, 0x020617)
    static let cardBorder = dyn(0xE2E8F0, 0x1E293B)
}

extension View {
    /// The web/Android post card: rounded surface, hairline border, one subtle
    /// shadow. Announcements get an amber edge.
    func postCard(announcement: Bool = false) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(announcement ? Theme.announce.opacity(0.45) : Theme.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
    }
}
