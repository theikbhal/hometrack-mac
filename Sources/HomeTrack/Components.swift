import SwiftUI
import AppKit

func rs(_ v: Double, _ dec: Int = 0) -> String { "₹" + String(format: "%.\(dec)f", v) }

func fmtLong(_ s: Int) -> String {
    let h = s / 3600, m = (s % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m \(s % 60)s"
}

struct Lift: ViewModifier {
    @State private var hover = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(hover ? 1.01 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hover)
            .onHover { hover = $0 }
    }
}

extension View {
    func card() -> some View {
        self.padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .modifier(Lift())
    }
}

struct LogoMark: View {
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.30, blue: 0.75),
                                              Color(red: 0.10, green: 0.60, blue: 0.62)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Text("₹").font(.system(size: size * 0.6, weight: .bold)).foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
    }
}

struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            LogoMark(size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("HomeTrack").font(.system(size: 19, weight: .bold, design: .rounded))
                Text("petrol · snacks · water").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// Slow, subtle drifting background
struct AnimatedBackground: View {
    @Environment(\.colorScheme) private var cs
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                (cs == .dark ? Color(red: 0.06, green: 0.07, blue: 0.09) : Color(red: 0.96, green: 0.97, blue: 0.98))
                GeometryReader { g in
                    ForEach(0..<4, id: \.self) { i in
                        blob(i: Double(i), t: t, size: g.size)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private func blob(i: Double, t: Double, size: CGSize) -> some View {
        let x = size.width * (0.5 + 0.35 * sin(t / 14 + i * 1.7))
        let y = size.height * (0.5 + 0.35 * cos(t / 16 + i * 1.1))
        return Circle()
            .fill(Color.teal.opacity(cs == .dark ? 0.10 : 0.12))
            .frame(width: 260 + i * 50, height: 260 + i * 50)
            .blur(radius: 60)
            .position(x: x, y: y)
    }
}

struct StatTile: View {
    let icon: String, title: String, value: String, tint: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.title3.bold().monospacedDigit())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }
}

struct CopyButton: View {
    let title: String
    let text: String
    @State private var done = false
    var body: some View {
        Button {
            copyToClipboard(text)
            done = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { done = false }
        } label: {
            Label(done ? "Copied ✓" : title, systemImage: done ? "checkmark" : "doc.on.doc")
        }
    }
}

struct PageTitle: View {
    let text: String
    var body: some View { Text(text).font(.largeTitle.bold()) }
}
