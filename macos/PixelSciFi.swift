import SwiftUI

// MARK: - Palette

enum NP {
    static let bg = PX.hex(0x0b0b1c)
    static let space = PX.hex(0x05051a)
    static let grid = PX.hex(0x1c1d44)
    static let cyan = PX.hex(0x34d4e6)
    static let cyanDim = PX.hex(0x1f6f8c)
    static let magenta = PX.hex(0xd93dba)
    static let purple = PX.hex(0x6b3dff)
    static let yellow = PX.hex(0xf0c040)
    static let red = PX.hex(0xff3d6e)
    static let white = PX.hex(0xd4e2ee)
    static let slate = PX.hex(0x5b6aa0)
    static func tone(_ used: Double) -> Color { used >= 90 ? red : used >= 70 ? yellow : cyan }
}

/// Pixel text with an RGB-split (chromatic aberration) and neon glow.
struct ChromaText: View {
    let text: String
    var s: CGFloat = 2
    var color: Color = NP.cyan
    var split: CGFloat = 1.5
    var body: some View {
        ZStack {
            PixelText(text: text, s: s, color: NP.magenta.opacity(0.45), shadow: nil).offset(x: -split)
            PixelText(text: text, s: s, color: NP.cyan.opacity(0.45), shadow: nil).offset(x: split)
            PixelText(text: text, s: s, color: color, shadow: nil)
        }
        .shadow(color: color.opacity(0.35), radius: 3)
    }
}

// MARK: - Energy bar

struct EnergyBar: View, Animatable {
    var progress: Double
    let tone: Color
    let t: Double
    var cells = 18
    var p: CGFloat = 2.5
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    static func width(cells: Int, p: CGFloat) -> CGFloat { CGFloat(cells * 3 + 5) * p }

    var body: some View {
        Canvas { ctx, size in
            func px(_ x: Int, _ y: Int, _ w: Int = 1, _ h: Int = 1, _ c: Color) {
                ctx.fill(Path(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: CGFloat(w) * p, height: CGFloat(h) * p)), with: .color(c))
            }
            let W = cells * 3 + 5
            // end brackets
            px(0, 0, 2, 1, tone); px(0, 0, 1, 7, tone); px(0, 6, 2, 1, tone)
            px(W - 2, 0, 2, 1, tone); px(W - 1, 0, 1, 7, tone); px(W - 2, 6, 2, 1, tone)
            var lit = Int((progress * Double(cells)).rounded())
            if progress > 0.001 && lit == 0 { lit = 1 }
            let flow = Int(t * 10) % (cells + 8)        // energy pulse travelling across lit cells
            for i in 0..<cells {
                let x = 3 + i * 3
                if i < lit {
                    px(x, 2, 2, 3, tone)
                    px(x, 2, 2, 1, i == flow || i == flow - 1 ? NP.white.opacity(0.8) : NP.white.opacity(0.25))
                } else {
                    px(x, 2, 2, 3, tone.opacity(0.10))
                }
            }
            // tick marks
            for i in stride(from: 0, through: cells, by: 3) { px(2 + i * 3, 8, 1, 1, NP.slate.opacity(0.8)) }
        }
        .frame(width: Self.width(cells: cells, p: p), height: 9 * p)
        .shadow(color: tone.opacity(0.3), radius: 2.5)
    }
}

// MARK: - Space scene with Clawd on thrusters

struct SpaceScene: View {
    let t: Double
    let worstUsed: Double?
    let offline: Bool
    static let size = CGSize(width: 120, height: 78)
    static let stars: [(Double, Double, Int)] = (0..<26).map { i in
        let a = Double((i * 73) % 97) / 97, b = Double((i * 41) % 89) / 89
        return (a, b, i % 3)
    }

    var body: some View {
        let used = worstUsed ?? 0
        let frame = Int(t * 12)
        let bob: CGFloat = (frame / 6) % 2 == 0 ? 0 : -2.5
        let p: CGFloat = 2
        ZStack(alignment: .topLeading) {
            Canvas { ctx, size in
                let w = size.width, h = size.height
                func dot(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: Color) {
                    ctx.fill(Path(CGRect(x: (x / p).rounded(.down) * p, y: (y / p).rounded(.down) * p, width: s, height: s)), with: .color(c))
                }
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(NP.space))
                // parallax starfield
                for (a, b, layer) in Self.stars {
                    let speed = [6.0, 14.0, 30.0][layer]
                    var x = a * Double(w) - t * speed
                    x = x.truncatingRemainder(dividingBy: Double(w)); if x < 0 { x += Double(w) }
                    let c: Color = layer == 2 ? NP.white.opacity(0.8) : layer == 1 ? NP.cyan.opacity(0.5) : NP.slate.opacity(0.8)
                    dot(CGFloat(x), CGFloat(b) * h, layer == 2 ? p * 1.5 : p, c)
                    if layer == 2 { dot(CGFloat(x) + p * 1.5, CGFloat(b) * h, p, NP.white.opacity(0.35)) }   // streak
                }
                // pixel planet
                let cx = w - 22, cy = h + 4, r: CGFloat = 24
                var y = cy - r
                while y < h {
                    var x = cx - r
                    while x < w {
                        let dx = x - cx, dy = y - cy
                        if dx * dx + dy * dy <= r * r {
                            let lightSide = dx + dy < -r * 0.9
                            let band = Int((y - (cy - r)) / (p * 3)) % 3 == 1
                            ctx.fill(Path(CGRect(x: x, y: y, width: p, height: p)),
                                     with: .color(lightSide ? NP.magenta.opacity(0.6) : band ? NP.purple.opacity(0.55) : NP.purple.opacity(0.35)))
                        }
                        x += p
                    }
                    y += p
                }
                // reticle corners
                for (x, y, sx, sy) in [(4.0, 4.0, 1.0, 1.0), (w - 4, 4, -1, 1), (4, h - 4, 1, -1), (w - 4, h - 4, -1, -1)] {
                    ctx.fill(Path(CGRect(x: min(x, x + sx * 8), y: y - (sy < 0 ? p : 0), width: 8, height: p)), with: .color(NP.cyanDim))
                    ctx.fill(Path(CGRect(x: x - (sx < 0 ? p : 0), y: min(y, y + sy * 8), width: p, height: 8)), with: .color(NP.cyanDim))
                }
            }
            // Clawd + thrusters
            ZStack(alignment: .topLeading) {
                Sprite(rows: Sprites.clawd(blink: frame % 40 < 2), palette: Sprites.clawdPalette, p: 3)
                    .shadow(color: PX.clawd.opacity(0.45), radius: 3)
                ForEach([4, 6, 11, 13], id: \.self) { leg in
                    let len = 1 + (frame + leg) % 3
                    VStack(spacing: 0) {
                        ForEach(0..<len, id: \.self) { k in
                            Rectangle().fill(k == 0 ? NP.yellow : k == 1 ? PX.orange : NP.red.opacity(0.8))
                                .frame(width: 3, height: 3)
                        }
                    }
                    .offset(x: CGFloat(leg) * 3, y: 30)
                    .shadow(color: PX.orange.opacity(0.5), radius: 2)
                }
            }
            .offset(x: 22, y: 14 + bob)
            // alert glyph
            if offline || used >= 70 {
                let on = frame % 12 < 7
                PixelText(text: "!", s: 2, color: offline ? PX.orange : NP.tone(used), shadow: nil)
                    .shadow(color: NP.tone(used), radius: 4)
                    .opacity(on ? 1 : 0.15)
                    .offset(x: 8, y: 8)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .padding(3)
        .background(PixelFrame(fill: NP.space, border: NP.cyanDim, p: 3, shadow: false))
    }
}

// MARK: - Columns & panel

struct NeonColumn: View {
    let item: LimitItem
    let now: Date
    let t: Double
    var animateIn = true
    @State private var shown: Double = 0
    static let cells = 20

    var body: some View {
        let tone = NP.tone(item.used)
        let critBlink = item.used < 90 || Int(t * 3) % 2 == 0
        let name = item.title == "SESSION" || item.title == "WEEKLY" ? item.title : item.title
        let tag = item.title == "SESSION" ? "5H" : "7D"
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 6) {
                PixelText(text: (item.active ? "> " : "") + name, s: 1.5, color: item.active ? tone : NP.white, shadow: nil)
                    .shadow(color: (item.active ? tone : NP.white).opacity(0.2), radius: 2)
                    .padding(.bottom, 1)
                Spacer(minLength: 2)
                ChromaText(text: "\(Int(item.remaining.rounded()))%", s: 2.5, color: tone)
                    .opacity(critBlink ? 1 : 0.35)
            }
            EnergyBar(progress: animateIn ? shown : item.remaining / 100, tone: tone, t: t, cells: Self.cells)
            HStack(spacing: 6) {
                PixelText(text: "T-" + pixelCountdown(item.resetsAt, now: now), s: 1.5, color: NP.slate, shadow: nil)
                Spacer(minLength: 2)
                PixelText(text: tag, s: 1.5, color: NP.slate.opacity(0.7), shadow: nil)
            }
        }
        .frame(width: EnergyBar.width(cells: Self.cells, p: 2.5))
        .fixedSize()
        .help(item.resetsAt.map { "Resets \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")
        .onAppear {
            guard animateIn else { return }
            withAnimation(.linear(duration: 0.8).delay(0.2)) { shown = item.remaining / 100 }
        }
        .onChange(of: item.remaining) { _, v in withAnimation(.linear(duration: 0.4)) { shown = v / 100 } }
    }
}

struct PixelGrid: View {
    var body: some View {
        Canvas { ctx, size in
            var d = Path()
            var x: CGFloat = 6
            while x < size.width {
                var y: CGFloat = 6
                while y < size.height { d.addRect(CGRect(x: x, y: y, width: 1.5, height: 1.5)); y += 12 }
                x += 12
            }
            ctx.fill(d, with: .color(NP.grid))
        }
        .allowsHitTesting(false)
    }
}

struct NeonPixelPanel: View {
    @ObservedObject var model: QuotaModel
    var frozenTime: Date? = nil

    var body: some View {
        if let d = frozenTime {
            content(t: d.timeIntervalSinceReferenceDate, now: d)
        } else {
            TimelineView(.periodic(from: .now, by: 1.0 / 12)) { ctx in
                content(t: ctx.date.timeIntervalSinceReferenceDate, now: ctx.date)
            }
        }
    }

    func content(t: Double, now: Date) -> some View {
        let worst = model.items.map(\.used).max()
        let offline = model.error != nil && model.items.isEmpty
        let (status, statusColor): (String, Color) = offline ? ("NO SIGNAL", PX.orange)
            : worst == nil ? ("BOOTING" + String(repeating: ".", count: Int(t * 3) % 4), NP.slate)
            : worst! >= 90 ? ("CRITICAL - RECHARGING", NP.red)
            : worst! >= 70 ? ("POWER LOW", NP.yellow)
            : ("SYSTEMS NOMINAL", NP.cyan)
        let caret = Int(t * 2) % 2 == 0 ? "_" : " "
        let linkOK = model.error == nil
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 4) {
                    ChromaText(text: "CLAUDE", s: 2, color: NP.cyan)
                    PixelText(text: "//USAGE", s: 2, color: NP.white.opacity(0.85), shadow: nil)
                }
                PixelText(text: "> " + status + caret, s: 1.5, color: statusColor, shadow: nil)
                    .shadow(color: statusColor.opacity(0.3), radius: 2)
                    .padding(.leading, 6)
                Spacer(minLength: 20)
                HStack(spacing: 5) {
                    Rectangle().fill(linkOK ? NP.cyan : PX.orange).frame(width: 4, height: 4)
                        .shadow(color: linkOK ? NP.cyan : PX.orange, radius: 3)
                        .opacity(Int(t * 2) % 2 == 0 ? 1 : 0.3)
                    PixelText(text: model.loading ? "SYNCING" : linkOK ? "LINK" : "LINK LOST", s: 1.5,
                              color: linkOK ? NP.cyan : PX.orange, shadow: nil)
                }
                PixelText(text: model.updatedAt.map { $0.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) } ?? "--:--",
                          s: 1.5, color: NP.slate, shadow: nil)
                Button { model.refresh() } label: {
                    Sprite(rows: Sprites.refresh, palette: ["Y": NP.cyan], p: 2)
                        .rotationEffect(.degrees(model.loading ? Double(Int(t * 4) % 4) * 90 : 0))
                        .shadow(color: NP.cyan.opacity(0.4), radius: 2)
                        .frame(width: 24, height: 22)
                        .background(PixelFrame(fill: NP.bg, border: NP.cyanDim, p: 2, shadow: false))
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            HStack(alignment: .center, spacing: 18) {
                SpaceScene(t: t, worstUsed: worst, offline: offline)
                if model.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ChromaText(text: offline ? "NO SIGNAL" : "SCANNING...", s: 2, color: offline ? PX.orange : NP.cyan)
                        ForEach(wrap(model.error ?? "", width: 44), id: \.self) { PixelText(text: $0, s: 1.5, color: NP.slate, shadow: nil) }
                    }
                    .frame(width: 440, alignment: .leading)
                } else {
                    ForEach(model.items) { NeonColumn(item: $0, now: now, t: t, animateIn: frozenTime == nil) }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, max(model.topInset, 4) + 14)
        .padding(.bottom, 17)
        .background(
            ZStack {
                PixelFrame(fill: NP.bg, border: NP.cyanDim, light: NP.grid, dark: NP.grid, p: 3)
                PixelGrid().padding(6).padding(.trailing, 3).padding(.bottom, 3)
                LinearGradient(colors: [NP.purple.opacity(0.09), .clear], startPoint: .top, endPoint: .center)
                    .padding(6).padding(.trailing, 3).padding(.bottom, 3)
                Scanlines(spacing: 3).opacity(0.18).padding(6).padding(.trailing, 3).padding(.bottom, 3)
            }
        )
        .shadow(color: NP.cyan.opacity(0.12), radius: 6)
    }
}
