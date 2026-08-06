import SwiftUI

struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let animationInterval: TimeInterval = 1.0 / 30.0

    var body: some View {
        if reduceTransparency {
            LinearGradient(
                colors: baseGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        } else if reduceMotion {
            glassLayer(time: 0)
        } else {
            TimelineView(.periodic(from: .now, by: animationInterval)) { context in
                glassLayer(time: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private var baseGradientColors: [Color] {
        if colorScheme == .dark {
            return [Color(red: 0.05, green: 0.12, blue: 0.18), Color(red: 0.07, green: 0.16, blue: 0.2), Color(red: 0.08, green: 0.13, blue: 0.17)]
        }
        return [Color(red: 0.92, green: 0.96, blue: 1.0), Color(red: 0.94, green: 1.0, blue: 0.97), Color(red: 1.0, green: 0.96, blue: 0.92)]
    }

    private var accentBlue: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.18, green: 0.52, blue: 0.7), Color.clear]
            : [Color(red: 0.56, green: 0.86, blue: 1.0), Color.clear]
    }

    private var accentMint: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.18, green: 0.64, blue: 0.52), Color.clear]
            : [Color(red: 0.48, green: 0.95, blue: 0.82), Color.clear]
    }

    private var accentCoral: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.73, green: 0.52, blue: 0.3), Color.clear]
            : [Color(red: 1.0, green: 0.78, blue: 0.65), Color.clear]
    }

    @ViewBuilder
    private func glassLayer(time: TimeInterval) -> some View {
        let driftA = CGFloat(sin(time / 9.0) * 80)
        let driftB = CGFloat(cos(time / 11.0) * 90)
        let driftC = CGFloat(sin(time / 13.0) * 70)
        ZStack {
            LinearGradient(
                colors: baseGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(radialGlow(colors: accentBlue))
                .frame(width: 340, height: 340)
                .offset(x: -140 + driftA, y: -220 + driftB)
                .blur(radius: 110)

            Circle()
                .fill(radialGlow(colors: accentMint))
                .frame(width: 400, height: 400)
                .offset(x: 160 + driftB, y: -40 + driftC)
                .blur(radius: 130)

            Circle()
                .fill(radialGlow(colors: accentCoral))
                .frame(width: 440, height: 440)
                .offset(x: -60 + driftC, y: 260 + driftA)
                .blur(radius: 140)
        }
        .drawingGroup()
    }

    private func radialGlow(colors: [Color]) -> RadialGradient {
        RadialGradient(colors: colors, center: .center, startRadius: 0, endRadius: 240)
    }
}
