import SwiftUI

// MARK: - Palette (Sweetie 16)

enum PX {
    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
    static let ink = hex(0x1a1c2c), plum = hex(0x5d275d), red = hex(0xe04a5f), orange = hex(0xef7d57)
    static let yellow = hex(0xffcd75), lime = hex(0xa7f070), green = hex(0x38b764), navy = hex(0x29366f)
    static let blue = hex(0x3b5dc9), sky = hex(0x41a6f6), cyan = hex(0x73eff7), white = hex(0xf4f4f4)
    static let silver = hex(0x94b0c2), slate = hex(0x566c86), charcoal = hex(0x333c57), darkRed = hex(0xb13e53)
    static let clawd = hex(0xd97757), clawdShade = hex(0xa85b43), clawdLight = hex(0xeba085)

    /// (bar, highlight, text) by percent used
    static func tone(_ used: Double) -> (Color, Color, Color) {
        used >= 90 ? (darkRed, red, red) : used >= 70 ? (hex(0xe8a33d), yellow, yellow) : (green, lime, lime)
    }
}

// MARK: - 5×7 bitmap font

enum PixelFont {
    static let raw: [Character: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
        "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
        ":": [".....", "..#..", "..#..", ".....", "..#..", "..#..", "....."],
        "-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
        ".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
        ",": [".....", ".....", ".....", ".....", ".##..", "..#..", ".#..."],
        "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
        "!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
        "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
        ">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
        ")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
    ]
    static let glyphs: [Character: [(Int, Int)]] = raw.mapValues { rows in
        rows.enumerated().flatMap { y, r in r.enumerated().compactMap { x, c in c == "#" ? (x, y) : nil } }
    }
    static func width(_ text: String, _ s: CGFloat) -> CGFloat { CGFloat(max(text.count * 6 - 1, 0)) * s }
}

struct PixelText: View {
    let text: String
    var s: CGFloat = 2
    var color: Color = PX.white
    var shadow: Color? = PX.ink

    var body: some View {
        let chars = Array(text.uppercased())
        let pad: CGFloat = shadow == nil ? 0 : s
        Canvas { ctx, _ in
            func draw(_ d: CGFloat, _ c: Color) {
                var p = Path()
                for (i, ch) in chars.enumerated() {
                    for (x, y) in PixelFont.glyphs[ch] ?? [] {
                        p.addRect(CGRect(x: CGFloat(i * 6 + x) * s + d, y: CGFloat(y) * s + d, width: s, height: s))
                    }
                }
                ctx.fill(p, with: .color(c))
            }
            if let sh = shadow { draw(s, sh) }
            draw(0, color)
        }
        .frame(width: PixelFont.width(text, s) + pad, height: 7 * s + pad)
    }
}

// MARK: - Sprites

struct Sprite: View {
    let rows: [String]
    let palette: [Character: Color]
    var p: CGFloat = 3

    var body: some View {
        let w = rows.map(\.count).max() ?? 0
        Canvas { ctx, _ in
            for (y, row) in rows.enumerated() {
                for (x, c) in row.enumerated() {
                    guard let col = palette[c] else { continue }
                    ctx.fill(Path(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: p + 0.3, height: p + 0.3)), with: .color(col))
                }
            }
        }
        .frame(width: CGFloat(w) * p, height: CGFloat(rows.count) * p)
    }
}

enum Sprites {
    static func clawd(blink: Bool) -> [String] {
        [
            "...LLLLLLLLLLLL...",
            "...OOOOOOOOOOOO...",
            blink ? "...OOOOOOOOOOOO..." : "...OOEOOOOOOEOO...",
            "...OOEOOOOOOEOO...",
            ".OOOOOOOOOOOOOOOO.",
            ".OOOOOOOOOOOOOOOO.",
            "...OOOOOOOOOOOO...",
            "...SSSSSSSSSSSS...",
            "....O.O....O.O....",
            "....S.S....S.S....",
        ]
    }
    static let clawdPalette: [Character: Color] = ["O": PX.clawd, "S": PX.clawdShade, "L": PX.clawdLight, "E": PX.ink]

    static let heart = [".RR.RR.", "RWRRRRR", "RRRRRRR", ".RRRRR.", "..RRR..", "...R..."]
    static let star = ["...Y...", "..YYY..", "YYYWYYY", ".YYYYY.", "..YYY..", ".YY.YY.", ".Y...Y."]
    static let potion = ["..BBB..", "..W.W..", "..W.W..", ".WPPPW.", "WPCPPPW", "WPPPPPW", ".WWWWW."]
    static let iconPalette: [Character: Color] = [
        "R": PX.red, "W": PX.white, "Y": PX.yellow, "B": PX.clawdShade, "P": PX.sky, "C": PX.cyan,
    ]
    static let drop = [".C", "CC", "CW"]
    static let refresh = ["..YYY.Y", ".Y...YY", "Y...YYY", "Y......", "Y.....Y", ".Y...Y.", "..YYY.."]
    static let tail = ["KWWK", "KWK.", "KK..", "K..."]
}

// MARK: - Frames & bars

/// Box with stepped (pixel-rounded) corners, a 1px border and a hard drop shadow.
struct PixelFrame: View {
    var fill: Color
    var border: Color
    var light: Color? = nil
    var dark: Color? = nil
    var p: CGFloat = 3
    var shadow = true

    static func shape(_ r: CGRect, _ p: CGFloat) -> Path {
        var s = Path()
        s.addRect(CGRect(x: r.minX + 2 * p, y: r.minY, width: r.width - 4 * p, height: r.height))
        s.addRect(CGRect(x: r.minX + p, y: r.minY + p, width: r.width - 2 * p, height: r.height - 2 * p))
        s.addRect(CGRect(x: r.minX, y: r.minY + 2 * p, width: r.width, height: r.height - 4 * p))
        return s
    }

    var body: some View {
        Canvas { ctx, size in
            let body = CGRect(x: 0, y: 0, width: size.width - (shadow ? p : 0), height: size.height - (shadow ? p : 0))
            if shadow { ctx.fill(Self.shape(body.offsetBy(dx: p, dy: p), p), with: .color(.black.opacity(0.45))) }
            ctx.fill(Self.shape(body, p), with: .color(border))
            let inner = body.insetBy(dx: p, dy: p)
            ctx.fill(Self.shape(inner, p), with: .color(fill))
            if let l = light { ctx.fill(Path(CGRect(x: inner.minX + 2 * p, y: inner.minY, width: inner.width - 4 * p, height: p)), with: .color(l)) }
            if let d = dark { ctx.fill(Path(CGRect(x: inner.minX + 2 * p, y: inner.maxY - p, width: inner.width - 4 * p, height: p)), with: .color(d)) }
        }
    }
}

struct PixelBar: View, Animatable {
    var progress: Double        // remaining, 0–1
    let used: Double
    var blocks = 24
    var p: CGFloat = 3
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    static func width(blocks: Int, p: CGFloat) -> CGFloat { CGFloat(blocks * 4 + 3) * p }

    var body: some View {
        let (bar, hi, _) = PX.tone(used)
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size)
            ctx.fill(PixelFrame.shape(r, p / 1.5), with: .color(PX.slate))
            ctx.fill(Path(r.insetBy(dx: p, dy: p)), with: .color(PX.ink))
            var lit = Int((progress * Double(blocks)).rounded())
            if progress > 0 && lit == 0 { lit = 1 }
            for i in 0..<blocks {
                let x = CGFloat(2 + i * 4) * p, y = 2 * p
                if i < lit {
                    ctx.fill(Path(CGRect(x: x, y: y, width: 3 * p, height: 3 * p)), with: .color(bar))
                    ctx.fill(Path(CGRect(x: x, y: y, width: 3 * p, height: p)), with: .color(hi))
                    ctx.fill(Path(CGRect(x: x, y: y, width: p, height: p)), with: .color(PX.white.opacity(0.8)))
                } else {
                    ctx.fill(Path(CGRect(x: x, y: y, width: 3 * p, height: 3 * p)), with: .color(PX.charcoal))
                }
            }
        }
        .frame(width: Self.width(blocks: blocks, p: p), height: 7 * p)
    }
}

// MARK: - Pieces

func pixelCountdown(_ d: Date?, now: Date) -> String {
    guard let d = d else { return "--:--:--" }
    let s = max(0, Int(d.timeIntervalSince(now)))
    let days = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60, sec = s % 60
    let hms = String(format: "%02d:%02d:%02d", h, m, sec)
    return days > 0 ? "\(days)D \(hms)" : hms
}

func wrap(_ text: String, width: Int) -> [String] {
    var lines: [String] = [], cur = ""
    for w in text.uppercased().split(separator: " ") {
        if cur.isEmpty { cur = String(w) }
        else if cur.count + 1 + w.count <= width { cur += " " + w }
        else { lines.append(cur); cur = String(w) }
    }
    if !cur.isEmpty { lines.append(cur) }
    return lines
}

struct PixelRow: View {
    let item: LimitItem
    let t: Double
    let now: Date
    var animateIn = true
    @State private var shown: Double = 0
    static let barBlocks = 24

    var body: some View {
        let (_, _, text) = PX.tone(item.used)
        let blinkOn = item.used < 90 || Int(t * 2) % 2 == 0
        let icon = item.title == "SESSION" ? Sprites.heart : item.title == "WEEKLY" ? Sprites.star : Sprites.potion
        HStack(alignment: .top, spacing: 10) {
            Sprite(rows: icon, palette: Sprites.iconPalette, p: 3).padding(.top, 1)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom, spacing: 8) {
                    PixelText(text: item.title, s: 2, color: PX.white)
                    PixelText(text: item.subtitle, s: 1.5, color: PX.slate, shadow: nil).padding(.bottom, 2)
                    Spacer(minLength: 4)
                    PixelText(text: "\(Int(item.remaining.rounded()))%", s: 2, color: text).opacity(blinkOn ? 1 : 0.25)
                }
                PixelBar(progress: animateIn ? shown : item.remaining / 100, used: item.used, blocks: Self.barBlocks)
                HStack(spacing: 6) {
                    PixelText(text: "RESET IN", s: 1.5, color: PX.slate, shadow: nil)
                    PixelText(text: pixelCountdown(item.resetsAt, now: now), s: 1.5, color: PX.silver, shadow: nil)
                    Spacer(minLength: 4)
                    if item.active {
                        PixelText(text: "> ACTIVE", s: 1.5, color: text, shadow: nil)
                    }
                }
            }
            .frame(width: PixelBar.width(blocks: Self.barBlocks, p: 3))
        }
        .help(item.resetsAt.map { "Resets \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")
        .onAppear {
            guard animateIn else { return }
            withAnimation(.linear(duration: 0.7).delay(0.2)) { shown = item.remaining / 100 }
        }
        .onChange(of: item.remaining) { _, v in withAnimation(.linear(duration: 0.4)) { shown = v / 100 } }
    }
}

struct Portrait: View {
    let t: Double
    let worstUsed: Double?
    let error: Bool
    static let size = CGSize(width: 152, height: 150)
    static let stars: [(CGFloat, CGFloat, Int)] = [(14, 50, 0), (40, 64, 2), (118, 48, 1), (136, 80, 3), (26, 88, 1), (104, 72, 0), (74, 54, 3)]

    var body: some View {
        let used = worstUsed ?? 0
        let tick = Int(t * 4)
        let bob: CGFloat = (tick / 2) % 2 == 0 ? 0 : -3
        let blink = tick % 14 == 0
        let (msg, col): (String, Color) = error ? ("UH OH...", PX.orange)
            : worstUsed == nil ? ("LOADING" + String(repeating: ".", count: tick % 4), PX.silver)
            : used >= 90 ? ("RUNNING HOT!", PX.red)
            : used >= 70 ? ("PACE YOURSELF", PX.yellow)
            : ("ALL CLEAR!", PX.green)
        ZStack(alignment: .topLeading) {
            PixelFrame(fill: PX.navy, border: PX.slate, light: PX.blue.opacity(0.5), shadow: false)
            // twinkling stars
            ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, s in
                let on = (tick + s.2) % 4 != 0
                Rectangle().fill(on ? PX.white : PX.silver.opacity(0.4))
                    .frame(width: on && (tick + s.2) % 4 == 1 ? 3 : 2, height: on && (tick + s.2) % 4 == 1 ? 3 : 2)
                    .offset(x: s.0, y: s.1)
            }
            // speech bubble
            VStack(alignment: .leading, spacing: 0) {
                PixelText(text: msg, s: 1.5, color: col == PX.silver ? PX.slate : PX.ink, shadow: nil)
                    .padding(.horizontal, 7).padding(.vertical, 6)
                    .background(PixelFrame(fill: PX.white, border: PX.ink, p: 2, shadow: false))
                    .overlay(alignment: .leading) { Rectangle().fill(col).frame(width: 2).padding(.vertical, 5).padding(.leading, 3) }
                Sprite(rows: Sprites.tail, palette: ["W": PX.white, "K": PX.ink], p: 2).offset(x: 30, y: -2)
            }
            .offset(x: 8, y: 9)
            // ground
            VStack(spacing: 0) {
                Canvas { ctx, size in
                    var x: CGFloat = 0, i = 0
                    while x < size.width {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: 3, height: 3)), with: .color(i % 3 == 0 ? PX.lime : PX.green))
                        ctx.fill(Path(CGRect(x: x, y: 3, width: 3, height: 3)), with: .color(i % 4 == 1 ? PX.lime : PX.green))
                        ctx.fill(Path(CGRect(x: x, y: 6, width: 3, height: 9)), with: .color(i % 5 == 2 ? PX.plum : PX.charcoal))
                        x += 3; i += 1
                    }
                }
                .frame(width: Self.size.width - 6, height: 15)
            }
            .offset(x: 3, y: Self.size.height - 18)
            // Clawd + mood props
            ZStack(alignment: .topLeading) {
                Sprite(rows: Sprites.clawd(blink: blink), palette: Sprites.clawdPalette, p: 4)
                if used >= 70 && !error {
                    Sprite(rows: Sprites.drop, palette: ["C": PX.cyan, "W": PX.white], p: 3)
                        .offset(x: 70, y: -6 + CGFloat(tick % 3) * 3)
                }
            }
            .offset(x: 40, y: Self.size.height - 18 - 40 + bob)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

struct PixelScene: View {
    let t: Double
    let worstUsed: Double?
    static let size = CGSize(width: 104, height: 66)
    static let stars: [(CGFloat, CGFloat, Int)] = [(10, 10, 0), (30, 22, 2), (82, 9, 1), (92, 26, 3), (56, 14, 1)]

    var body: some View {
        let used = worstUsed ?? 0
        let tick = Int(t * 4)
        let bob: CGFloat = (tick / 2) % 2 == 0 ? 0 : -3
        ZStack(alignment: .topLeading) {
            PixelFrame(fill: PX.navy, border: PX.slate, light: PX.blue.opacity(0.5), shadow: false)
            ForEach(Array(Self.stars.enumerated()), id: \.offset) { _, s in
                let phase = (tick + s.2) % 4
                Rectangle().fill(phase == 0 ? PX.silver.opacity(0.4) : PX.white)
                    .frame(width: phase == 1 ? 3 : 2, height: phase == 1 ? 3 : 2)
                    .offset(x: s.0, y: s.1)
            }
            Canvas { ctx, size in
                var x: CGFloat = 0, i = 0
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 3, height: 3)), with: .color(i % 3 == 0 ? PX.lime : PX.green))
                    ctx.fill(Path(CGRect(x: x, y: 3, width: 3, height: 6)), with: .color(i % 5 == 2 ? PX.plum : PX.charcoal))
                    x += 3; i += 1
                }
            }
            .frame(width: Self.size.width - 6, height: 9)
            .offset(x: 3, y: Self.size.height - 12)
            ZStack(alignment: .topLeading) {
                Sprite(rows: Sprites.clawd(blink: tick % 14 == 0), palette: Sprites.clawdPalette, p: 3)
                if used >= 70 {
                    Sprite(rows: Sprites.drop, palette: ["C": PX.cyan, "W": PX.white], p: 2)
                        .offset(x: 54, y: -4 + CGFloat(tick % 3) * 2)
                }
            }
            .offset(x: 25, y: Self.size.height - 12 - 30 + bob)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

struct PixelColumn: View {
    let item: LimitItem
    let now: Date
    let t: Double
    var animateIn = true
    @State private var shown: Double = 0
    static let blocks = 12

    var body: some View {
        let (_, _, tone) = PX.tone(item.used)
        let blinkOn = item.used < 90 || Int(t * 2) % 2 == 0
        let icon = item.title == "SESSION" ? Sprites.heart : item.title == "WEEKLY" ? Sprites.star : Sprites.potion
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Sprite(rows: icon, palette: Sprites.iconPalette, p: 2)
                PixelText(text: item.title, s: 1.5, color: item.active ? tone : PX.white)
                Spacer(minLength: 2)
                PixelText(text: "\(Int(item.remaining.rounded()))%", s: 2, color: tone).opacity(blinkOn ? 1 : 0.25)
            }
            PixelBar(progress: animateIn ? shown : item.remaining / 100, used: item.used, blocks: Self.blocks)
            PixelText(text: "RESET " + pixelCountdown(item.resetsAt, now: now), s: 1.5, color: PX.slate, shadow: nil)
        }
        .frame(width: PixelBar.width(blocks: Self.blocks, p: 3))
        .help(item.resetsAt.map { "Resets \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")
        .onAppear {
            guard animateIn else { return }
            withAnimation(.linear(duration: 0.7).delay(0.2)) { shown = item.remaining / 100 }
        }
        .onChange(of: item.remaining) { _, v in withAnimation(.linear(duration: 0.4)) { shown = v / 100 } }
    }
}

struct PixelPanel: View {
    @ObservedObject var model: QuotaModel
    var frozenTime: Date? = nil

    var body: some View {
        if let d = frozenTime {
            content(t: d.timeIntervalSinceReferenceDate, now: d)
        } else {
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                content(t: ctx.date.timeIntervalSinceReferenceDate, now: ctx.date)
            }
        }
    }

    func content(t: Double, now: Date) -> some View {
        let tick = Int(t * 4)
        let worst = model.items.map(\.used).max()
        let (mood, moodColor): (String, Color) = model.error != nil && model.items.isEmpty ? ("UH OH", PX.orange)
            : worst == nil ? ("LOADING" + String(repeating: ".", count: tick % 4), PX.silver)
            : worst! >= 90 ? ("RUNNING HOT!", PX.red)
            : worst! >= 70 ? ("PACE YOURSELF", PX.yellow)
            : ("ALL CLEAR!", PX.lime)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                PixelText(text: "CLAUDE USAGE", s: 2, color: PX.white)
                PixelText(text: "> " + mood, s: 1.5, color: moodColor, shadow: nil)
                Spacer(minLength: 20)
                if model.error != nil && !model.items.isEmpty {
                    PixelText(text: "! SYNC FAILED", s: 1.5, color: PX.orange, shadow: nil)
                }
                PixelText(text: model.updatedAt.map { "SYNC " + $0.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) } ?? "SYNC --:--",
                          s: 1.5, color: PX.slate, shadow: nil)
                Button { model.refresh() } label: {
                    Sprite(rows: Sprites.refresh, palette: ["Y": PX.yellow], p: 2)
                        .rotationEffect(.degrees(model.loading ? Double(tick % 4) * 90 : 0))
                        .frame(width: 24, height: 22)
                        .background(PixelFrame(fill: PX.charcoal, border: PX.silver, p: 2, shadow: false))
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            HStack(alignment: .center, spacing: 18) {
                PixelScene(t: t, worstUsed: worst)
                if model.items.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        PixelText(text: model.error == nil ? "LOADING..." : "NO SIGNAL", s: 2, color: model.error == nil ? PX.silver : PX.orange)
                        ForEach(wrap(model.error ?? "", width: 40), id: \.self) { PixelText(text: $0, s: 1.5, color: PX.silver, shadow: nil) }
                    }
                    .frame(width: 420, alignment: .leading)
                } else {
                    ForEach(model.items) { PixelColumn(item: $0, now: now, t: t, animateIn: frozenTime == nil) }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, max(model.topInset, 4) + 14)
        .padding(.bottom, 17)
        .background(PixelFrame(fill: PX.ink, border: PX.silver, light: PX.charcoal, dark: PX.charcoal, p: 3))
    }
}
