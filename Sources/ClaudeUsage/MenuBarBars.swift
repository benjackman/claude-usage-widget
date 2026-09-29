import SwiftUI

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case text, bars, barsAndPercent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .text: return "Text"
        case .bars: return "Bars"
        case .barsAndPercent: return "Bars + %"
        }
    }
}

/// Renders two stacked mini progress bars (session on top, weekly below) as a template
/// image. MenuBarExtra labels only display Text/Image, so custom views must be rasterised.
@MainActor
enum MenuBarBars {
    static func image(session: Double, weekly: Double, showPercent: Bool) -> NSImage {
        let renderer = ImageRenderer(content: Content(session: session, weekly: weekly, showPercent: showPercent))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        // Template images take the menu bar's colour, so this works in light, dark and tinted bars.
        image.isTemplate = true
        return image
    }

    private struct Content: View {
        let session: Double
        let weekly: Double
        let showPercent: Bool

        var body: some View {
            HStack(spacing: 4) {
                VStack(spacing: 3) {
                    Bar(percent: session)
                    Bar(percent: weekly)
                }
                if showPercent {
                    VStack(alignment: .trailing, spacing: -1) {
                        Text("\(Int(session.rounded()))%")
                        Text("\(Int(weekly.rounded()))%")
                    }
                    .font(.system(size: 8, weight: .semibold).monospacedDigit())
                }
            }
            .foregroundStyle(.black)
            .frame(height: 18)
            .padding(.horizontal, 1)
        }
    }

    private struct Bar: View {
        let percent: Double
        private let width: CGFloat = 34

        var body: some View {
            ZStack(alignment: .leading) {
                Capsule().opacity(0.3)
                Capsule().frame(width: max(2.5, width * min(percent, 100) / 100))
            }
            .frame(width: width, height: 5)
        }
    }
}
