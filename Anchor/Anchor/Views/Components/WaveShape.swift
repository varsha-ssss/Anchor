import SwiftUI

struct WaveBottomShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let waveHeight: CGFloat = 22

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - waveHeight))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.85, y: h - waveHeight),
            control2: CGPoint(x: w * 0.68, y: h)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h - waveHeight),
            control1: CGPoint(x: w * 0.32, y: h),
            control2: CGPoint(x: w * 0.15, y: h - waveHeight)
        )
        path.closeSubpath()
        return path
    }
}

struct BubbleShape: Shape {
    var cornerRadius: CGFloat = 20
    enum TailSide { case leading, trailing }
    var tailSide: TailSide = .leading

    func path(in rect: CGRect) -> Path {
        let tailSize: CGFloat = 8
        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailSize)
        var path = Path(roundedRect: bubbleRect, cornerRadius: cornerRadius)

        let tailX: CGFloat = tailSide == .leading ? rect.minX + cornerRadius + 6 : rect.maxX - cornerRadius - 6
        path.move(to: CGPoint(x: tailX - tailSize, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: tailX, y: rect.maxY))
        path.addLine(to: CGPoint(x: tailX + tailSize, y: bubbleRect.maxY))
        path.closeSubpath()
        return path
    }
}
