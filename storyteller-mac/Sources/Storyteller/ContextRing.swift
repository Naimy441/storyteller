import SwiftUI

/// Small ring showing how full the model's context window will be on the next turn.
struct ContextRing: View {
    let adventure: Adventure
    @Environment(Store.self) private var store
    @State private var showDetails = false
    @State private var hover = false

    var body: some View {
        let usage = Prompt.usage(adventure, scale: store.tokenScale[adventure.id])
        let tint = Self.tint(usage.fraction)
        Button { showDetails.toggle() } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: max(usage.fraction, 0.02))
                        .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: usage.fraction)
                }
                .frame(width: 15, height: 15)
                Text("\(Int((usage.fraction * 100).rounded()))%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(usage.fraction >= 0.7 ? tint : Theme.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(hover || showDetails ? 0.07 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Context: \(Int(usage.fraction * 100))% used")
        .popover(isPresented: $showDetails, arrowEdge: .top) {
            ContextDetails(usage: usage, tint: tint)
        }
    }

    static func tint(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.7: Theme.accent
        case ..<0.9: Color(red: 1, green: 0.6, blue: 0.3)
        default: Color(red: 1, green: 0.42, blue: 0.4)
        }
    }
}

private struct ContextDetails: View {
    let usage: ContextUsage
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Context").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(usage.calibrated ? "" : "≈ ")\(usage.total.formatted()) / \(usage.window.formatted()) tokens")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(Theme.secondary)
            }

            // Stacked bar of where the space goes.
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(segments, id: \.0) { _, value, color in
                        if value > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: max(3, g.size.width * Double(value) / Double(usage.window)))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 8)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06)))

            VStack(spacing: 7) {
                ForEach(segments, id: \.0) { name, value, color in
                    HStack(spacing: 8) {
                        Circle().fill(color).frame(width: 7, height: 7)
                        Text(name).font(.system(size: 12))
                        Spacer()
                        Text(value.formatted()).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.secondary)
                    }
                }
            }

            Theme.hairline.frame(height: 1)

            Text(note)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 290)
    }

    private var segments: [(String, Int, Color)] {
        [
            ("AI instructions", usage.instructions, Color(red: 0.55, green: 0.70, blue: 1.0)),
            ("Plot, summary & note", usage.plot, Color(red: 0.76, green: 0.62, blue: 1.0)),
            ("Active story cards", usage.cards, Color(red: 0.50, green: 0.85, blue: 0.62)),
            ("Story history", usage.history, Theme.accent),
            ("Reserved for reply", usage.reserve, Color.white.opacity(0.3)),
        ]
    }

    private var note: String {
        let base = usage.turnsIncluded < usage.turnsTotal
            ? "Sending the last \(usage.turnsIncluded) of \(usage.turnsTotal) passages. Older ones drop out — keep key facts in Plot Essentials or the Summary."
            : "The whole story fits. Change how much the AI remembers with Story memory in Settings."
        return base + (usage.calibrated
            ? " Counts are matched to Ollama's exact token count from your latest turn."
            : " Counts are estimates until Ollama reports its exact count.")
    }
}
