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
}
