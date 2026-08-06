import SwiftUI

struct GlassSurface<Content: View>: View {
    private let cornerRadius: CGFloat
    private let contentPadding: EdgeInsets
    private let content: Content

    init(
        cornerRadius: CGFloat = 28,
        contentPadding: EdgeInsets = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(contentPadding)
            .background(
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(LinearGradient(colors: sheenColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(shape.stroke(borderColor, lineWidth: 1))
            .shadow(color: shadowColor, radius: 18, x: 0, y: 12)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var sheenColors: [Color] {
        if colorScheme == .dark {
            return [Color.white.opacity(0.08), Color.black.opacity(0.2)]
        }
        return [Color.white.opacity(0.32), Color.white.opacity(0.12)]
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.4)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.12)
    }
}
