import SwiftUI

enum Palette {
    static let gold = Color(red: 0.96, green: 0.86, blue: 0.54)
    static let mist = Color(red: 0.56, green: 0.72, blue: 1.00)
    static let starlight = Color(red: 0.86, green: 0.88, blue: 1.00)
    static let ink = Color(red: 0.95, green: 0.93, blue: 0.97)
    static let nightTop = Color(red: 0.04, green: 0.04, blue: 0.12)
    static let nightBottom = Color(red: 0.11, green: 0.08, blue: 0.25)
    static let nebula = Color(red: 1.00, green: 0.60, blue: 0.76)
    static let pressedInk = Color(red: 0.16, green: 0.13, blue: 0.00)
    static let rose = Color(red: 1.00, green: 0.66, blue: 0.72)
    static let aqua = Color(red: 0.60, green: 0.86, blue: 0.90)

    /// One colour per line, so layers stay legible against each other.
    static let lineColours = [gold, rose, aqua]
    static func line(_ index: Int) -> Color {
        lineColours[((index % lineColours.count) + lineColours.count) % lineColours.count]
    }
}
