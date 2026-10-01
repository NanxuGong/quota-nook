import SwiftUI

// MARK: - Time of day

enum SceneKind: String, CaseIterable {
    case morning, afternoon, evening
    static func at(_ d: Date) -> SceneKind {
        let h = Calendar.current.component(.hour, from: d)
        return (5..<11).contains(h) ? .morning : (11..<17).contains(h) ? .afternoon : .evening
    }
    var quotes: [String] {
        switch self {
        case .morning: return ["Small steps, big ideas.", "Fresh context, fresh start.", "Good morning. Let's build something kind."]
        case .afternoon: return ["A calmer mind, a brighter tomorrow.", "Deep work, gentle pace.", "One thoughtful commit at a time."]
        case .evening: return ["Thinking further together.", "Rest is part of the work.", "Tomorrow's ideas are already on their way."]
        }
    }
}

struct ScenePalette {
    let text: Color, dim: Color, track: Color, scrim: Color, hot: Color, border: Color
    let bars: [Color], codexBars: [Color]

    static func of(_ k: SceneKind) -> ScenePalette {
        switch k {
        case .morning:
            return ScenePalette(text: PX.hex(0x2a211d), dim: PX.hex(0x8a766f), track: PX.hex(0xe4cfc8).opacity(0.9),
                                scrim: PX.hex(0xfff7f3).opacity(0.62), hot: PX.hex(0xe0694a), border: .white.opacity(0.7),
                                bars: [PX.hex(0xec7a55), PX.hex(0xf2c14e), PX.hex(0xc9a084)],
                                codexBars: [PX.hex(0x4f9eaa), PX.hex(0x79bfc4)])
        case .afternoon:
            return ScenePalette(text: .white, dim: .white.opacity(0.72), track: .white.opacity(0.22),
                                scrim: Color.black.opacity(0.34), hot: PX.hex(0xffb37a), border: .white.opacity(0.16),
                                bars: [PX.hex(0xf0805a), PX.hex(0xf5cf6a), PX.hex(0xfbeee0)],
                                codexBars: [PX.hex(0x66b8c7), PX.hex(0x9ad5d8)])
        case .evening:
            return ScenePalette(text: .white, dim: .white.opacity(0.72), track: .white.opacity(0.22),
                                scrim: PX.hex(0x1c1830).opacity(0.36), hot: PX.hex(0xffab7a), border: .white.opacity(0.16),
                                bars: [PX.hex(0xf5906a), PX.hex(0xf7d27a), PX.hex(0xfbe9d8)],
                                codexBars: [PX.hex(0x58aebf), PX.hex(0x8bcbd3)])
        }
    }
}

// MARK: - Drawing helpers

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

private func flower(_ ctx: GraphicsContext, _ c: CGPoint, _ r: CGFloat, _ rot: Double, _ petal: Color, _ core: Color) {
    for k in 0..<5 {
        let a = rot + Double(k) * 2 * .pi / 5
        let e = Path(ellipseIn: CGRect(x: -r * 0.48, y: -r, width: r * 0.96, height: r * 1.05))
            .applying(CGAffineTransform(rotationAngle: a))
            .applying(CGAffineTransform(translationX: c.x, y: c.y))
        ctx.fill(e, with: .color(petal))
    }
    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.26, y: c.y - r * 0.26, width: r * 0.52, height: r * 0.52)), with: .color(core))
}

private func cloud(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: Color) {
    var p = Path()
    for (dx, dy, r) in [(0.0, 0.0, 16.0), (18, -8, 20), (40, -2, 17), (56, 4, 12), (-14, 6, 11)] {
        p.addEllipse(in: CGRect(x: x + CGFloat(dx) * s - CGFloat(r) * s, y: y + CGFloat(dy) * s - CGFloat(r) * s,
                                width: CGFloat(r) * 2 * s, height: CGFloat(r) * 2 * s))
    }
    p.addRect(CGRect(x: x - 14 * s, y: y + 2 * s, width: 70 * s, height: 14 * s))
    ctx.fill(p, with: .color(c))
}

private func wrapMod(_ v: Double, _ m: Double) -> Double { let r = v.truncatingRemainder(dividingBy: m); return r < 0 ? r + m : r }

// MARK: - Morning: cherry blossoms

struct MorningScene: View {
    let t: Double
    var body: some View {
        Canvas { ctx, size in Self.draw(ctx, size, t) }
    }

    static func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let W = size.width, H = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [PX.hex(0xfdf1eb), PX.hex(0xf8e1d9)]), startPoint: .zero, endPoint: pt(0, H)))
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [Color.white.opacity(0.85), .clear]), center: pt(W * 0.52, -10), startRadius: 0, endRadius: 200))

        // distant hills + mist
        var far = Path()
        far.move(to: pt(0, H)); far.addCurve(to: pt(W * 0.5, H - 34), control1: pt(W * 0.18, H - 60), control2: pt(W * 0.32, H - 26))
        far.addCurve(to: pt(W, H - 46), control1: pt(W * 0.68, H - 44), control2: pt(W * 0.86, H - 70))
        far.addLine(to: pt(W, H)); far.closeSubpath()
        ctx.fill(far, with: .color(PX.hex(0xf3d2ca)))
        var near = Path()
        near.move(to: pt(W * 0.3, H)); near.addCurve(to: pt(W, H - 22), control1: pt(W * 0.55, H - 30), control2: pt(W * 0.8, H - 12))
        near.addLine(to: pt(W, H)); near.closeSubpath()
        ctx.fill(near, with: .color(PX.hex(0xeec3ba).opacity(0.8)))
        cloud(ctx, W * 0.62, H - 22, 1.1, .white.opacity(0.55))
        cloud(ctx, W * 0.86, H - 34, 0.9, .white.opacity(0.5))

        // grassy mound for the mascot
        ctx.fill(Path(ellipseIn: CGRect(x: -60, y: H - 52, width: 290, height: 110)), with: .color(PX.hex(0xd9dcc0)))
        ctx.fill(Path(ellipseIn: CGRect(x: -40, y: H - 44, width: 230, height: 90)), with: .color(PX.hex(0xc8d2a8)))

        // tree trunk + branches
        let bark = GraphicsContext.Shading.color(PX.hex(0x6e4a3d))
        var trunk = Path()
        trunk.move(to: pt(-6, H - 30)); trunk.addCurve(to: pt(26, 8), control1: pt(24, H - 80), control2: pt(4, 50))
        ctx.stroke(trunk, with: bark, style: StrokeStyle(lineWidth: 11, lineCap: .round))
        var b1 = Path(); b1.move(to: pt(22, 22)); b1.addCurve(to: pt(210, 12), control1: pt(70, 44), control2: pt(140, -6))
        ctx.stroke(b1, with: bark, style: StrokeStyle(lineWidth: 5, lineCap: .round))
        var b2 = Path(); b2.move(to: pt(90, 30)); b2.addCurve(to: pt(150, 64), control1: pt(110, 44), control2: pt(128, 58))
        ctx.stroke(b2, with: bark, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        var b3 = Path(); b3.move(to: pt(15, 70)); b3.addCurve(to: pt(-10, 110), control1: pt(4, 86), control2: pt(0, 96))
        ctx.stroke(b3, with: bark, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        var b4 = Path(); b4.move(to: pt(160, 14)); b4.addCurve(to: pt(250, 30), control1: pt(190, 4), control2: pt(226, 14))
        ctx.stroke(b4, with: bark, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        let blossoms: [(CGFloat, CGFloat, CGFloat)] = [
            (40, 30, 9), (62, 18, 11), (84, 36, 8), (104, 20, 10), (126, 8, 9), (150, 16, 11), (176, 6, 8), (198, 18, 10),
            (118, 44, 8), (140, 58, 10), (156, 70, 7), (6, 58, 10), (18, 92, 9), (-2, 104, 8), (34, 50, 7),
            (226, 22, 8), (248, 34, 9), (212, 38, 6), (72, 52, 6), (186, 30, 6),
        ]
        for (i, b) in blossoms.enumerated() {
            let petal = i % 3 == 0 ? PX.hex(0xf7c4cf) : i % 3 == 1 ? PX.hex(0xf4b3c1) : PX.hex(0xfad3da)
            flower(ctx, pt(b.0, b.1), b.2, Double(i) * 0.7, petal, PX.hex(0xe0849b))
        }
        // blossom bush behind the mascot
        let bush: [(CGFloat, CGFloat, CGFloat)] = [(150, 150, 8), (170, 140, 9), (190, 152, 7), (12, 150, 8), (30, 162, 7), (160, 164, 6)]
        for (i, b) in bush.enumerated() {
            flower(ctx, pt(b.0, H - 184 + b.1), b.2, Double(i), PX.hex(0xf6bfcb), PX.hex(0xe0849b))
        }

        // drifting petals
        for i in 0..<18 {
            let seed = Double(i)
            let speed = 14 + wrapMod(seed * 7.3, 12)
            let x = wrapMod(seed * 97 + t * speed, Double(W) + 40) - 20
            let y = wrapMod(seed * 53 + t * speed * 0.55, Double(H) + 20) - 10 + sin(t * 1.3 + seed) * 5
            let rot = t * (0.8 + wrapMod(seed, 3) * 0.3) + seed
            let petal = Path(ellipseIn: CGRect(x: -3.5, y: -2, width: 7, height: 4))
                .applying(CGAffineTransform(rotationAngle: rot))
                .applying(CGAffineTransform(translationX: x, y: y))
            ctx.fill(petal, with: .color(PX.hex(i % 2 == 0 ? 0xf2a9b9 : 0xf7c6d1).opacity(0.9)))
        }
    }
}

// MARK: - Afternoon: sunlit room

struct AfternoonScene: View {
    let t: Double
    var body: some View {
        Canvas { ctx, size in Self.draw(ctx, size, t) }
    }

    static func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let W = size.width, H = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [PX.hex(0x6a4a36), PX.hex(0x3a2a21)]), startPoint: .zero, endPoint: pt(0, H)))

        // big window behind the mascot
        let win = CGRect(x: 18, y: -6, width: 170, height: 120)
        ctx.fill(Path(roundedRect: win, cornerRadius: 4),
                 with: .linearGradient(Gradient(colors: [PX.hex(0xffe2ad), PX.hex(0xf6b56a)]), startPoint: pt(0, win.minY), endPoint: pt(0, win.maxY)))
        ctx.fill(Path(ellipseIn: CGRect(x: 60, y: -40, width: 150, height: 120)),
                 with: .radialGradient(Gradient(colors: [Color.white.opacity(0.7), .clear]), center: pt(130, 10), startRadius: 0, endRadius: 80))
        for x in [win.midX] { ctx.fill(Path(CGRect(x: x - 3, y: win.minY, width: 6, height: win.height)), with: .color(PX.hex(0x5b3e2d))) }
        ctx.fill(Path(CGRect(x: win.minX, y: 52, width: win.width, height: 6)), with: .color(PX.hex(0x5b3e2d)))
        ctx.stroke(Path(roundedRect: win, cornerRadius: 4), with: .color(PX.hex(0x4a3226)), lineWidth: 7)

        // second window on the right
        let w2 = CGRect(x: W - 64, y: 8, width: 100, height: 92)
        ctx.fill(Path(roundedRect: w2, cornerRadius: 3),
                 with: .linearGradient(Gradient(colors: [PX.hex(0xf9d6a4), PX.hex(0xe9a76a)]), startPoint: pt(0, w2.minY), endPoint: pt(0, w2.maxY)))
        ctx.fill(Path(CGRect(x: w2.midX - 2.5, y: w2.minY, width: 5, height: w2.height)), with: .color(PX.hex(0x5b3e2d)))
        ctx.fill(Path(CGRect(x: w2.minX, y: w2.midY - 2.5, width: w2.width, height: 5)), with: .color(PX.hex(0x5b3e2d)))
        ctx.stroke(Path(roundedRect: w2, cornerRadius: 3), with: .color(PX.hex(0x4a3226)), lineWidth: 6)

        // light shafts
        let shimmer = 0.13 + 0.03 * sin(t * 0.8)
        var shaft = Path()
        shaft.move(to: pt(30, 0)); shaft.addLine(to: pt(190, 0)); shaft.addLine(to: pt(360, H)); shaft.addLine(to: pt(170, H)); shaft.closeSubpath()
        ctx.fill(shaft, with: .linearGradient(Gradient(colors: [PX.hex(0xffe2b0).opacity(shimmer), .clear]), startPoint: pt(100, 0), endPoint: pt(260, H)))
        var shaft2 = Path()
        shaft2.move(to: pt(W - 64, 8)); shaft2.addLine(to: pt(W, 8)); shaft2.addLine(to: pt(W - 60, H)); shaft2.addLine(to: pt(W - 170, H)); shaft2.closeSubpath()
        ctx.fill(shaft2, with: .linearGradient(Gradient(colors: [PX.hex(0xffe2b0).opacity(shimmer * 0.7), .clear]), startPoint: pt(W - 30, 8), endPoint: pt(W - 120, H)))

        // hanging plant, top-left
        for i in 0..<9 {
            let a = Double(i) * 0.5 + 0.3
            let leaf = Path(ellipseIn: CGRect(x: -5, y: 0, width: 10, height: 22))
                .applying(CGAffineTransform(rotationAngle: a - 1.2 + sin(t * 0.7 + Double(i)) * 0.04))
                .applying(CGAffineTransform(translationX: 8 + CGFloat(i) * 7, y: CGFloat(i % 3) * 6))
            ctx.fill(leaf, with: .color(i % 2 == 0 ? PX.hex(0x6f8f4e) : PX.hex(0x557540)))
        }

        // desk
        ctx.fill(Path(CGRect(x: 0, y: H - 42, width: W, height: 42)),
                 with: .linearGradient(Gradient(colors: [PX.hex(0x8a5a3b), PX.hex(0x5a3824)]), startPoint: pt(0, H - 42), endPoint: pt(0, H)))
        ctx.fill(Path(CGRect(x: 0, y: H - 42, width: W, height: 2.5)), with: .color(PX.hex(0xb57c52)))
        ctx.fill(Path(CGRect(x: 170, y: H - 40, width: 200, height: 20)),
                 with: .linearGradient(Gradient(colors: [PX.hex(0xffd9a0).opacity(0.25), .clear]), startPoint: pt(170, 0), endPoint: pt(370, 0)))

        // books
        for (i, c) in [PX.hex(0x8c4a3a), PX.hex(0x3f5a6b), PX.hex(0xc49a5a)].enumerated() {
            ctx.fill(Path(roundedRect: CGRect(x: -14 + CGFloat(i) * 2, y: H - 50 - CGFloat(i) * 7, width: 46 - CGFloat(i) * 4, height: 7), cornerRadius: 1.5), with: .color(c))
        }

        // laptop
        var lid = Path()
        lid.move(to: pt(40, H - 44)); lid.addLine(to: pt(48, H - 98)); lid.addLine(to: pt(122, H - 98)); lid.addLine(to: pt(126, H - 44)); lid.closeSubpath()
        ctx.fill(lid, with: .linearGradient(Gradient(colors: [PX.hex(0x55565e), PX.hex(0x34353b)]), startPoint: pt(42, H - 98), endPoint: pt(126, H - 44)))
        ctx.fill(Path(ellipseIn: CGRect(x: 79, y: H - 76, width: 10, height: 10)), with: .color(Color.white.opacity(0.18)))
        ctx.fill(Path(roundedRect: CGRect(x: 30, y: H - 46, width: 112, height: 5), cornerRadius: 2), with: .color(PX.hex(0x9c9ca6)))

        // mug + steam
        let mx = W - 250, my = H - 66
        ctx.stroke(Path(ellipseIn: CGRect(x: mx + 20, y: my + 6, width: 12, height: 12)), with: .color(PX.hex(0xe6dace)), lineWidth: 3)
        ctx.fill(Path(roundedRect: CGRect(x: mx, y: my, width: 26, height: 26), cornerRadius: 5), with: .color(PX.hex(0xefe5d8)))
        ctx.fill(Path(ellipseIn: CGRect(x: mx + 2, y: my - 2, width: 22, height: 6)), with: .color(PX.hex(0x6b4632)))
        for k in 0..<2 {
            var s = Path()
            let base = mx + 8 + CGFloat(k) * 9
            s.move(to: pt(base, my - 4))
            for j in 1...8 {
                let y = my - 4 - CGFloat(j) * 3.5
                let x = base + CGFloat(sin(t * 2 + Double(j) * 0.7 + Double(k) * 2)) * 3
                s.addLine(to: pt(x, y))
            }
            ctx.stroke(s, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        // plant, bottom-right
        let px = W - 44, py = H - 44
        var pot = Path()
        pot.move(to: pt(px - 18, py - 30)); pot.addLine(to: pt(px + 18, py - 30)); pot.addLine(to: pt(px + 13, py)); pot.addLine(to: pt(px - 13, py)); pot.closeSubpath()
        ctx.fill(pot, with: .color(PX.hex(0xb5643f)))
        for i in 0..<11 {
            let a = -2.6 + Double(i) * 0.2 + sin(t * 0.6 + Double(i)) * 0.03
            let leaf = Path(ellipseIn: CGRect(x: -6, y: -34, width: 12, height: 34))
                .applying(CGAffineTransform(rotationAngle: a + .pi / 2))
                .applying(CGAffineTransform(translationX: px, y: py - 30))
            ctx.fill(leaf, with: .color(i % 2 == 0 ? PX.hex(0x6f8f4e) : PX.hex(0x4f6e38)))
        }

        // dust motes in the light
        for i in 0..<22 {
            let s = Double(i)
            let x = 150 + wrapMod(s * 37 + t * (3 + wrapMod(s, 4)), 220)
            let y = wrapMod(s * 29 - t * (2 + wrapMod(s * 1.7, 3)), Double(H))
            let a = 0.25 + 0.25 * sin(t * 1.5 + s)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(PX.hex(0xffe8c0).opacity(a)))
        }

        // vignette
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [.clear, Color.black.opacity(0.35)]), center: pt(W * 0.35, H * 0.4), startRadius: 120, endRadius: W * 0.75))
    }
}

// MARK: - Evening: dusk mountains

struct EveningScene: View {
    let t: Double
    var body: some View {
        Canvas { ctx, size in Self.draw(ctx, size, t) }
    }

    static func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let W = size.width, H = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(stops: [.init(color: PX.hex(0x2c2952), location: 0), .init(color: PX.hex(0x5f4577), location: 0.4),
                             .init(color: PX.hex(0xc07470), location: 0.68), .init(color: PX.hex(0xf0a36f), location: 0.8)]),
            startPoint: .zero, endPoint: pt(0, H)))

        // stars
        for i in 0..<34 {
            let s = Double(i)
            let x = wrapMod(s * 83.7, Double(W)), y = wrapMod(s * 41.3, Double(H) * 0.42)
            let a = 0.35 + 0.45 * (0.5 + 0.5 * sin(t * (1 + wrapMod(s, 3) * 0.6) + s))
            let r: CGFloat = i % 7 == 0 ? 2 : 1.2
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(a)))
        }
        // sunset glow
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(Gradient(colors: [PX.hex(0xffc58f).opacity(0.75), .clear]), center: pt(W * 0.58, H * 0.8), startRadius: 0, endRadius: 190))
        // clouds
        // crescent moon with a soft halo
        let moon = CGRect(x: 128, y: 14, width: 26, height: 26)
        ctx.fill(Path(ellipseIn: moon.insetBy(dx: -16, dy: -16)),
                 with: .radialGradient(Gradient(colors: [PX.hex(0xfff1d6).opacity(0.35), .clear]), center: pt(moon.midX, moon.midY), startRadius: 0, endRadius: 30))
        let crescent = Path(ellipseIn: moon).subtracting(Path(ellipseIn: moon.offsetBy(dx: 8, dy: -5)))
        ctx.fill(crescent, with: .color(PX.hex(0xfff0d0)))
        let drift = CGFloat(sin(t * 0.15)) * 6
        cloud(ctx, 50 + drift, 34, 0.9, PX.hex(0xf3dccb).opacity(0.85))

        // mountains (far → near)
        func ridge(_ pts: [(CGFloat, CGFloat)], _ c: Color) {
            var p = Path()
            p.move(to: pt(0, H))
            for (x, y) in pts { p.addLine(to: pt(x * W, y)) }
            p.addLine(to: pt(W, H)); p.closeSubpath()
            ctx.fill(p, with: .color(c))
        }
        ridge([(0, 118), (0.08, 104), (0.16, 112), (0.28, 90), (0.36, 106), (0.5, 96), (0.62, 108), (0.72, 84), (0.8, 70), (0.88, 92), (0.95, 80), (1, 90)],
              PX.hex(0x8a5d84).opacity(0.85))
        ridge([(0, 128), (0.1, 112), (0.2, 124), (0.32, 108), (0.44, 126), (0.56, 118), (0.7, 124), (0.82, 96), (0.9, 110), (1, 102)],
              PX.hex(0x5c4373))
        ridge([(0, 132), (0.06, 118), (0.18, 128), (0.3, 138), (0.5, 140), (0.66, 136), (0.78, 122), (0.86, 128), (1, 118)],
              PX.hex(0x3a2c51))

        // lake with shimmering reflections
        let lakeY = H - 34
        ctx.fill(Path(CGRect(x: 0, y: lakeY, width: W, height: 34)),
                 with: .linearGradient(Gradient(colors: [PX.hex(0x7a577b), PX.hex(0x2a2242)]), startPoint: pt(0, lakeY), endPoint: pt(0, H)))
        for i in 0..<14 {
            let s = Double(i)
            let y = lakeY + 4 + CGFloat(wrapMod(s * 7, 26))
            let x = W * 0.58 - 60 + CGFloat(wrapMod(s * 31, 120)) + CGFloat(sin(t * 1.4 + s)) * 4
            let w = CGFloat(10 + wrapMod(s * 13, 26))
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: 1.6), cornerRadius: 1), with: .color(PX.hex(0xffc08a).opacity(0.45)))
        }
        // near shore + pines on the left
        var shore = Path()
        shore.move(to: pt(0, H)); shore.addLine(to: pt(0, H - 44)); shore.addCurve(to: pt(220, H), control1: pt(80, H - 52), control2: pt(160, H - 30))
        shore.closeSubpath()
        ctx.fill(shore, with: .color(PX.hex(0x2a2040)))
        let pines: [(CGFloat, CGFloat)] = [(170, 26), (186, 18), (200, 22), (W - 30, 24), (W - 46, 16)]
        for (x, h) in pines {
            var tree = Path()
            let bx: CGFloat = x
            let by: CGFloat = x < 300 ? H - 20 - (x - 170) * 0.2 : lakeY + 2
            tree.move(to: pt(bx, by - h)); tree.addLine(to: pt(bx + 6, by)); tree.addLine(to: pt(bx - 6, by)); tree.closeSubpath()
            ctx.fill(tree, with: .color(PX.hex(0x221a35)))
        }
    }
}

// MARK: - Mascot

struct Ear: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r.minX, r.maxY))
        p.addQuadCurve(to: pt(r.midX, r.minY), control: pt(r.minX + r.width * 0.1, r.minY + r.height * 0.2))
        p.addQuadCurve(to: pt(r.maxX, r.maxY), control: pt(r.maxX - r.width * 0.1, r.minY + r.height * 0.2))
        p.closeSubpath()
        return p
    }
}

struct Blob: View {
    enum Mood { case content, dozing, happy }
    let mood: Mood
    let t: Double

    var body: some View {
        let breathe = 1 + 0.02 * sin(t * (mood == .happy ? 3 : 1.8))
        let skin = RadialGradient(colors: [PX.hex(0xffc4a2), PX.hex(0xf68b5f), PX.hex(0xe2683f)],
                                  center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 58)
        let ink = PX.hex(0x5a2e1e)
        let wave = mood == .happy ? sin(t * 5) * 18 : 0
        ZStack {
            Ellipse().fill(Color.black.opacity(0.2)).frame(width: 74, height: 12).blur(radius: 3).offset(y: 44)
            Ellipse().fill(PX.hex(0xe2683f)).frame(width: 24, height: 14).offset(x: -17, y: 37)
            Ellipse().fill(PX.hex(0xe2683f)).frame(width: 24, height: 14).offset(x: 17, y: 37)
            Ear().fill(skin).frame(width: 18, height: 20).rotationEffect(.degrees(-18)).offset(x: -22, y: -33)
            Ear().fill(skin).frame(width: 18, height: 20).rotationEffect(.degrees(18)).offset(x: 22, y: -33)
            Capsule().fill(PX.hex(0xee7a4f)).frame(width: 16, height: 26).rotationEffect(.degrees(35)).offset(x: -40, y: 10)
            Capsule().fill(PX.hex(0xee7a4f)).frame(width: 16, height: 26)
                .rotationEffect(.degrees(-35 - wave), anchor: .bottom).offset(x: 40, y: mood == .happy ? -2 : 10)
            Ellipse().fill(skin).frame(width: 86, height: 76)
            Ellipse().fill(Color.white.opacity(0.25)).frame(width: 26, height: 14).rotationEffect(.degrees(-25)).offset(x: -18, y: -22)
            // face
            Group {
                switch mood {
                case .happy:
                    Ellipse().fill(ink).frame(width: 7, height: 9).offset(x: -13, y: -4)
                    Ellipse().fill(ink).frame(width: 7, height: 9).offset(x: 13, y: -4)
                    Circle().fill(.white).frame(width: 2.5, height: 2.5).offset(x: -12, y: -6)
                    Circle().fill(.white).frame(width: 2.5, height: 2.5).offset(x: 14, y: -6)
                default:
                    ClosedEye().stroke(ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round)).frame(width: 12, height: 5).offset(x: -13, y: -3)
                    ClosedEye().stroke(ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round)).frame(width: 12, height: 5).offset(x: 13, y: -3)
                }
                Smile().stroke(ink, style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 8, height: 3.5).offset(y: 8)
                Ellipse().fill(PX.hex(0xff8f8f).opacity(0.5)).frame(width: 12, height: 7).offset(x: -25, y: 7)
                Ellipse().fill(PX.hex(0xff8f8f).opacity(0.5)).frame(width: 12, height: 7).offset(x: 25, y: 7)
            }
            if mood == .dozing {
                let ph = wrapMod(t * 0.4, 1)
                Text("z").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.8 * (1 - ph)))
                    .offset(x: 40 + ph * 10, y: -40 - ph * 18)
            }
        }
        .scaleEffect(x: 2 - breathe, y: breathe, anchor: .bottom)
        .frame(width: 110, height: 100)
    }
}

struct ClosedEye: Shape {        // ◡ content, closed eye
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r.minX, r.minY))
        p.addQuadCurve(to: pt(r.maxX, r.minY), control: pt(r.midX, r.maxY * 1.6))
        return p
    }
}

struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(r.minX, r.minY))
        p.addQuadCurve(to: pt(r.maxX, r.minY), control: pt(r.midX, r.maxY * 1.8))
        return p
    }
}

// MARK: - Pixel blob mascot

enum PixelBlob {
    static let palette: [Character: Color] = [
        "K": PX.hex(0x4a2418), "O": PX.hex(0xf08556), "L": PX.hex(0xffc09a), "D": PX.hex(0xcf623b),
        "E": PX.hex(0x2a1712), "M": PX.hex(0x7a3322), "P": PX.hex(0xff9c8f),
    ]

    /// 22×21 round critter with ears, dot eyes, blush, nub arms and feet.
    static func rows(eyesClosed: Bool, wave: Bool) -> [String] {
        let W = 22, H = 21
        var g = Array(repeating: Array(repeating: Character("."), count: W), count: H)
        func set(_ x: Int, _ y: Int, _ c: Character) { if x >= 0, x < W, y >= 0, y < H { g[y][x] = c } }

        // ears
        set(5, 0, "K"); set(16, 0, "K")
        for (x, y) in [(4, 1), (6, 1), (15, 1), (17, 1), (4, 2), (17, 2)] { set(x, y, "K") }
        for (x, y) in [(5, 1), (16, 1), (5, 2), (16, 2)] { set(x, y, "O") }
        for x in 6...15 { set(x, 2, "K") }
        // body rows: (y, left outline, right outline)
        var spans: [(Int, Int, Int)] = [(3, 4, 17), (4, 3, 18), (5, 2, 19)]
        for y in 6...14 { spans.append((y, 1, 20)) }
        spans += [(15, 2, 19), (16, 2, 19), (17, 3, 18)]
        for (y, l, r) in spans {
            set(l, y, "K"); set(r, y, "K")
            for x in (l + 1)..<r { set(x, y, "O") }
            set(r - 1, y, "D")
        }
        for x in 4...17 { set(x, 17, "D") }
        for x in 4...17 { set(x, 18, "K") }
        // rim highlight
        for (x, y) in [(6, 4), (7, 4), (8, 4), (4, 5), (5, 5), (3, 6), (3, 7)] { set(x, y, "L") }
        // arms
        set(0, 11, "K"); set(0, 12, "K"); set(1, 11, "O"); set(1, 12, "O")
        if wave {
            set(21, 7, "K"); set(21, 8, "K"); set(20, 7, "O"); set(20, 8, "D")
        } else {
            set(21, 11, "K"); set(21, 12, "K"); set(20, 11, "D"); set(20, 12, "D")
        }
        // feet
        for fx in [5, 13] {
            set(fx, 19, "K"); set(fx + 1, 19, "D"); set(fx + 2, 19, "D"); set(fx + 3, 19, "K")
            for x in fx...(fx + 3) { set(x, 20, "K") }
        }
        // face
        if eyesClosed {
            for x in [6, 7, 14, 15] { set(x, 11, "E") }
        } else {
            set(7, 10, "E"); set(7, 11, "E"); set(14, 10, "E"); set(14, 11, "E")
        }
        set(10, 13, "M"); set(11, 13, "M")
        set(5, 12, "P"); set(16, 12, "P")
        return g.map { String($0) }
    }
}

// MARK: - Pixel Clawd for the scenes

struct SceneClawd: View {
    let kind: SceneKind
    let t: Double

    var body: some View {
        let p: CGFloat = 4
        let tick = Int(t * 4)
        let blink = kind == .afternoon || tick % 18 == 0
        let dy: CGFloat
        switch kind {
        case .evening: dy = -[0, 2.5, 5, 7.5, 7.5, 5, 2.5, 0, 0, 0, 0, 0][tick % 12]   // little hops
        case .afternoon: dy = (tick / 6) % 2 == 0 ? 0 : 1.5                            // slow breathing
        case .morning: dy = (tick / 3) % 2 == 0 ? 0 : -2.5                              // idle bob
        }
        return ZStack {
            Ellipse().fill(Color.black.opacity(kind == .morning ? 0.12 : 0.28))
                .frame(width: 76 + dy * 2, height: 9).blur(radius: 2.5).offset(y: 42)
            Sprite(rows: PixelBlob.rows(eyesClosed: blink, wave: kind == .evening && (tick / 3) % 2 == 0),
                   palette: PixelBlob.palette, p: p)
                .offset(y: dy)
                .shadow(color: PX.clawd.opacity(kind == .morning ? 0 : 0.3), radius: 6)
            if kind == .afternoon {
                let ph = (tick / 2) % 6
                PixelText(text: ph < 3 ? "z" : "Z", s: ph < 3 ? 1.5 : 2, color: .white.opacity(0.85), shadow: nil)
                    .offset(x: 34 + CGFloat(ph) * 2.5, y: -46 - CGFloat(ph) * 4)
                    .opacity(ph == 5 ? 0.3 : 1)
            }
        }
        .frame(width: 120, height: 100)
    }
}

// MARK: - Panel

struct ScenicRow: View {
    let item: LimitItem
    let color: Color
    let pal: ScenePalette
    let now: Date
    var animateIn = true
    @State private var shown: Double = 0

    var body: some View {
        let name = item.title == "SESSION" ? "Session" : item.title == "WEEKLY" ? "Weekly" : item.title.capitalized
        let left = item.remaining
        let low = left <= 30
        HStack(spacing: 10) {
            Text(name).font(.system(size: 13.5, weight: .medium)).foregroundColor(pal.text)
                .frame(width: 70, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(pal.track)
                    Capsule().fill(color)
                        .frame(width: max(left > 0 ? 12 : 0, g.size.width * CGFloat((animateIn ? shown : left) / 100)))
                }
            }
            .frame(width: 145, height: 11)
            (Text("\(Int(left.rounded()))%").font(.system(size: 13.5, weight: .bold)).foregroundColor(low ? pal.hot : pal.text)
             + Text(" left").font(.system(size: 12.5)).foregroundColor(pal.dim))
                .monospacedDigit()
                .frame(width: 76, alignment: .leading)
            Text(item.resetsAt.map { "resets in " + shortCountdown($0, now: now) } ?? "")
                .font(.system(size: 11.5)).foregroundColor(pal.dim)
                .frame(width: 111, alignment: .leading)
        }
        .help(item.resetsAt.map { "\(item.displayName): \(Int(item.used.rounded()))% used · resets \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")
        .onAppear {
            guard animateIn else { return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.12)) { shown = left }
        }
        .onChange(of: item.remaining) { _, v in withAnimation(.easeInOut(duration: 0.5)) { shown = v } }
    }
}

struct ScenicSectionLabel: View {
    let title: String
    let accent: Color
    let status: String?
    let pal: ScenePalette

    var body: some View {
        HStack(spacing: 7) {
            Capsule().fill(accent).frame(width: 3, height: 12)
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.1).foregroundColor(pal.text.opacity(0.9))
            Spacer()
            if let status {
                Text(status).font(.system(size: 10.5, weight: .medium)).foregroundColor(pal.dim)
            }
        }
        .frame(height: 14)
    }
}

struct ScenicPanel: View {
    @ObservedObject var model: QuotaModel
    var actions: AppDelegate?
    var frozenTime: Date? = nil
    static let width: CGFloat = 736

    var body: some View {
        if let d = frozenTime {
            content(t: d.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000), now: d)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                content(t: ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100_000), now: ctx.date)
            }
        }
    }

    func kind(_ now: Date) -> SceneKind {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_USAGE_SCENE"], let k = SceneKind(rawValue: env) { return k }
        return SceneKind(rawValue: model.scene) ?? .at(now)
    }

    func resetLine(_ now: Date) -> String {
        if model.error != nil && model.codexError != nil { return "Sync paused" }
        let fresh = model.error == nil ? model.items : model.codexItems
        let target = fresh.first { $0.active && ($0.resetsAt ?? .distantPast) > now }
            ?? fresh.first { $0.title == "SESSION" && ($0.resetsAt ?? .distantPast) > now }
            ?? fresh.first { ($0.resetsAt ?? .distantPast) > now }
        guard let r = target?.resetsAt else { return "—" }
        return "Resets in " + shortCountdown(r, now: now)
    }

    func claudeRows() -> [LimitItem] {
        let session = model.items.first { $0.title == "SESSION" }
        let weekly = model.items.first { $0.title == "WEEKLY" }
        let fable = model.items.first { $0.title == "FABLE" }
            ?? model.items.first { $0.title != "SESSION" && $0.title != "WEEKLY" }
        return [session, weekly, fable].compactMap { $0 }
    }

    func content(t: Double, now: Date) -> some View {
        let k = kind(now)
        let pal = ScenePalette.of(k)
        let totalRows = max(claudeRows().count, 1) + max(model.codexItems.count, 1)
        let H = max(250, 137 + CGFloat(totalRows) * 27)
        let day = Calendar.current.ordinality(of: .day, in: .year, for: now) ?? 0
        let quote = k.quotes[day % k.quotes.count]
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return ZStack(alignment: .topLeading) {
            Group {
                switch k {
                case .morning: MorningScene(t: t)
                case .afternoon: AfternoonScene(t: t)
                case .evening: EveningScene(t: t)
                }
            }
            LinearGradient(stops: [.init(color: .clear, location: 0.2), .init(color: pal.scrim, location: 0.4), .init(color: pal.scrim, location: 1)],
                           startPoint: .leading, endPoint: .trailing)

            SceneClawd(kind: k, t: t)
                .position(x: k == .afternoon ? 150 : 92, y: H - (k == .afternoon ? 90 : k == .morning ? 74 : 72))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    Text("Usage").font(.system(size: 20, weight: .bold)).foregroundColor(pal.text)
                    Spacer(minLength: 16)
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 14, weight: .medium))
                        Text(resetLine(now)).font(.system(size: 13.5)).monospacedDigit()
                    }
                    .foregroundColor(pal.dim)
                    Button { model.refresh() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .semibold))
                            .foregroundColor(pal.text.opacity(model.loading || model.codexLoading ? 0.3 : 0.75))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }
                .padding(.bottom, 14)
                VStack(alignment: .leading, spacing: 7) {
                    ScenicSectionLabel(title: "Claude", accent: PX.clawd,
                                       status: model.error == nil ? nil : model.error!.contains("Session expired") ? "sign in again" : "sync paused", pal: pal)
                        .help(model.error ?? "Claude usage synced")
                    if claudeRows().isEmpty {
                        Text(model.error ?? "Loading Claude usage…").font(.system(size: 12.5)).foregroundColor(pal.dim)
                    } else {
                        ForEach(Array(claudeRows().enumerated()), id: \.element.id) { i, item in
                            ScenicRow(item: item, color: pal.bars[i % pal.bars.count], pal: pal, now: now, animateIn: frozenTime == nil)
                        }
                    }
                    ScenicSectionLabel(title: "Codex", accent: pal.codexBars[0],
                                       status: model.codexError != nil ? "sync paused" : nil, pal: pal)
                        .padding(.top, 3)
                        .help(model.codexError ?? "Codex usage synced")
                    if model.codexItems.isEmpty {
                        Text(model.codexError ?? "Loading Codex usage…").font(.system(size: 12.5)).foregroundColor(pal.dim)
                    } else {
                        ForEach(Array(model.codexItems.prefix(2).enumerated()), id: \.element.id) { i, item in
                            ScenicRow(item: item, color: pal.codexBars[i % pal.codexBars.count], pal: pal, now: now, animateIn: frozenTime == nil)
                        }
                    }
                }
            }
            .padding(.leading, 214).padding(.trailing, 20).padding(.top, 18)

            HStack(alignment: .lastTextBaseline) {
                Text("“\(quote)”").font(.system(size: 12.5).italic()).foregroundColor(pal.text.opacity(0.85))
                    .shadow(color: k == .morning ? .white.opacity(0.8) : .black.opacity(0.4), radius: 3)
                Spacer()
                if (model.error != nil && !model.items.isEmpty) || (model.codexError != nil && !model.codexItems.isEmpty) {
                    Text("sync paused").font(.system(size: 11)).foregroundColor(pal.dim).padding(.trailing, 10)
                }
                HStack(spacing: 6) {
                    ClaudeMark().frame(width: 17, height: 17)
                    Text("Claude").font(.system(size: 18, weight: .regular, design: .serif)).foregroundColor(pal.text)
                    Text("+").font(.system(size: 13, weight: .medium)).foregroundColor(pal.dim)
                    CodexMark(color: pal.codexBars[0]).frame(width: 16, height: 16)
                    Text("Codex").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(pal.text)
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 13)
            .frame(width: Self.width, height: H, alignment: .bottom)
        }
        .frame(width: Self.width, height: H)
        .clipShape(shape)
        .overlay(shape.stroke(pal.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .padding(.top, model.topInset + 8)
        .padding(.horizontal, 24).padding(.bottom, 30)
    }
}

/// Claude-style radial burst mark.
struct ClaudeMark: View {
    var color: Color = PX.hex(0xd97757)
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * .pi
                let len = r * (i % 2 == 0 ? 1.0 : 0.72)
                var p = Path()
                p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.16, y: c.y + CGFloat(sin(a)) * r * 0.16))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * len, y: c.y + CGFloat(sin(a)) * len))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: r * 0.2, lineCap: .round))
            }
        }
    }
}

/// A small geometric companion mark in the Codex cyan accent.
struct CodexMark: View {
    var color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.8), lineWidth: 1.6)
                .rotationEffect(.degrees(45)).scaleEffect(0.72)
            Circle().fill(color).frame(width: 4.5, height: 4.5)
        }
    }
}
