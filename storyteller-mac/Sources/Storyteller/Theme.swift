import SwiftUI

enum Theme {
    static let bg = Color(red: 0.051, green: 0.055, blue: 0.071)
    static let sidebar = Color(red: 0.067, green: 0.071, blue: 0.090)
    static let surface = Color(red: 0.090, green: 0.094, blue: 0.118)
    static let surface2 = Color(red: 0.114, green: 0.122, blue: 0.149)
    static let hairline = Color.white.opacity(0.07)
    static let text = Color(red: 0.925, green: 0.914, blue: 0.886)
    static let secondary = Color(red: 0.557, green: 0.573, blue: 0.627)
    static let tertiary = Color(red: 0.369, green: 0.384, blue: 0.439)
    static let accent = Color(red: 0.902, green: 0.722, blue: 0.408)
    static let accentDeep = Color(red: 0.851, green: 0.604, blue: 0.306)

    static func story(_ zoom: Double) -> Font { .system(size: 18 * zoom, design: .serif) }

    static func color(for type: CardType) -> Color {
        switch type {
        case .character: Color(red: 0.55, green: 0.70, blue: 1.0)
        case .location: Color(red: 0.50, green: 0.85, blue: 0.62)
        case .faction: Color(red: 0.76, green: 0.62, blue: 1.0)
        case .item: Color(red: 1.0, green: 0.70, blue: 0.45)
        case .lore: Color(red: 0.72, green: 0.74, blue: 0.80)
        }
    }
}

/// Small square icon button with a hover highlight.
struct IconButton: View {
    let icon: String
    var help: String = ""
    var size: CGFloat = 30
    var active = false
    let action: () -> Void
    @State private var hover = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(active ? Theme.accent : hover ? Theme.text : Theme.secondary)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(hover || active ? 0.07 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.3)
        .onHover { hover = $0 }
        .help(help)
    }
}

/// Uppercase section label with optional hint.
struct SectionLabel: View {
    let title: String
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.tertiary)
            if let hint {
                Text(hint).font(.system(size: 12)).foregroundStyle(Theme.secondary)
            }
        }
    }
}

/// Multi-line text area with a focus ring.
struct TextArea: View {
    @Binding var text: String
    var placeholder = ""
    var minHeight: CGFloat = 80
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 13))
            .lineSpacing(3)
            .foregroundStyle(Theme.text)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(.horizontal, 7)
            .padding(.vertical, 8)
            .frame(minHeight: minHeight)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder).font(.system(size: 13)).foregroundStyle(Theme.tertiary)
                        .padding(.horizontal, 12).padding(.vertical, 8).allowsHitTesting(false)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Theme.accent.opacity(0.45) : Theme.hairline))
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}

/// Single-line text field with a focus ring.
struct InputField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .focused($focused)
            .focusEffectDisabled()
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Theme.accent.opacity(0.45) : Theme.hairline))
    }
}

/// A menu that looks like an input field.
struct MenuField<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { o in Button(label(o)) { selection = o } }
        } label: {
            HStack {
                Text(label(selection)).font(.system(size: 13)).foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10)).foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hairline))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

/// Three pulsing dots shown while the model is thinking.
struct TypingDots: View {
    var body: some View {
        PhaseAnimator([0, 1, 2]) { phase in
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        .opacity(phase == i ? 1 : 0.25)
                }
            }
        } animation: { _ in .easeInOut(duration: 0.35) }
    }
}

/// Draggable divider that resizes the panel next to it.
struct ResizeHandle: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    /// True when the panel sits to the right of the handle (dragging left grows it).
    var panelOnRight = false
    @State private var startWidth: Double?
    @State private var hover = false

    var body: some View {
        Theme.hairline
            .frame(width: 1)
            .overlay {
                Rectangle()
                    .fill(Theme.accent.opacity(hover || startWidth != nil ? 0.6 : 0))
                    .frame(width: 2)
                    .animation(.easeOut(duration: 0.15), value: hover)
            }
            .overlay {
                Color.clear
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .pointerStyle(.columnResize)
                    .onHover { hover = $0 }
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { v in
                                let start = startWidth ?? width
                                startWidth = start
                                let delta = v.translation.width * (panelOnRight ? -1 : 1)
                                width = min(max(start + delta, range.lowerBound), range.upperBound)
                            }
                            .onEnded { _ in startWidth = nil }
                    )
            }
            .zIndex(10)
    }
}

/// Story text zoom, shared by the menu commands, pinch gesture and views.
enum TextZoom {
    static let key = "textZoom"
    static let range = 0.7...1.8
    static let step = 0.1

    static func clamp(_ v: Double) -> Double { min(max((v * 100).rounded() / 100, range.lowerBound), range.upperBound) }
}

extension View {
    /// Lets this area drag the window (we hide the system title bar).
    func windowDraggable() -> some View {
        gesture(WindowDragGesture())
    }
}
