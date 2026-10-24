import SwiftUI

struct AnchorTheme {
    static let primary = Color(hex: "2563EB")
    static let primaryForeground = Color.white

    static let background = Color(hex: "E0EDFF")
    static let backgroundDark = Color(hex: "0F1A2E")
    static let card = Color(hex: "EBF2FF")
    static let cardDark = Color(hex: "1A2744")

    static let foreground = Color(hex: "1E3A5F")
    static let foregroundDark = Color(hex: "CADAF0")
    static let mutedForeground = Color(hex: "6B8CAE")
    static let mutedForegroundDark = Color(hex: "7E9BBD")

    static let muted = Color(hex: "CADAF0")
    static let mutedDark = Color(hex: "253553")

    static let accent = Color(hex: "10B981")
    static let amber = Color(hex: "F59E0B")
    static let coral = Color(hex: "FB7C63")
    static let sand = Color(hex: "E8A855")
    static let seafoam = Color(hex: "2DD4BF")
    static let kelp = Color(hex: "0D9488")

    static let destructive = Color(hex: "f87171")
    static let rose = Color(hex: "FB7185")
    static let roseBackground = Color(hex: "FFF1F2")
    static let roseBorder = Color(hex: "FECDD3")

    static let border = Color(hex: "B0C7E8").opacity(0.5)
    static let borderDark = Color(hex: "2E4366").opacity(0.6)

    static let oceanGradient = LinearGradient(
        colors: [Color(hex: "60A5FA"), Color(hex: "2563EB")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let greenGradient = LinearGradient(
        colors: [Color(hex: "34D399"), Color(hex: "10B981")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let amberGradient = LinearGradient(
        colors: [Color(hex: "FBBF24"), Color(hex: "F59E0B")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let emergencyGradient = LinearGradient(
        colors: [Color(hex: "EF4444"), Color(hex: "DC2626")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let deepOceanGradient = LinearGradient(
        colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static func moodColor(_ mood: Int) -> Color {
        switch mood {
        case 1: return Color(hex: "f87171")
        case 2: return Color(hex: "fb923c")
        case 3: return Color(hex: "facc15")
        case 4: return Color(hex: "4ade80")
        case 5: return Color(hex: "2563EB")
        default: return Color.gray
        }
    }

    static func moodEmoji(_ mood: Int) -> String {
        switch mood {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😄"
        default: return "😐"
        }
    }

    static func moodLabel(_ mood: Int) -> String {
        switch mood {
        case 1: return "Rough"
        case 2: return "Not great"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great!"
        default: return "Okay"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct AnchorCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func anchorCard() -> some View {
        modifier(AnchorCardModifier())
    }
}
