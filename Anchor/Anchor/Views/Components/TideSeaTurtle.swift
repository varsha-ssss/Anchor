import SwiftUI

struct TideSeaTurtle: View {
    var size: CGFloat = 100

    var body: some View {
        Image("TideMascot")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

struct SpeechBubble: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(colorScheme == .dark ? AnchorTheme.foregroundDark : AnchorTheme.foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(colorScheme == .dark ? AnchorTheme.cardDark : AnchorTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(colorScheme == .dark ? AnchorTheme.borderDark : AnchorTheme.border, lineWidth: 1)
            )
    }
}
