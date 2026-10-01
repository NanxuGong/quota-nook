import SwiftUI

func shortCountdown(_ d: Date?, now: Date) -> String {
    guard let d = d else { return "—" }
    let s = max(0, Int(d.timeIntervalSince(now)))
    let days = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
    if days > 0 { return "\(days)d \(h)h" }
    if h > 0 { return "\(h)h \(m)m" }
    return "\(max(m, 1))m"
}

// MARK: - Terminal (Claude Code style, amber CRT)

enum TM {
    static let bg = PX.hex(0x0e0c0b)
    static let fg = PX.hex(0xe9dccf)
    static let amber = PX.hex(0xd97757)
    static let dim = PX.hex(0x76655a)
    static let faint = PX.hex(0x2c2521)
    static let yellow = PX.hex(0xe5b567)
    static let red = PX.hex(0xf06a6a)
    static let green = PX.hex(0x8fc97a)
    static func tone(_ used: Double) -> Color { used >= 90 ? red : used >= 70 ? yellow : amber }
    static func font(_ size: CGFloat = 12, _ w: Font.Weight = .regular) -> Font { .system(size: size, weight: w, design: .monospaced) }

    static func label(_ item: LimitItem) -> (String, String) {
        item.title == "SESSION" ? ("session", "5h")
            : item.title == "WEEKLY" ? ("weekly", "all models")
            : ("weekly", item.title.lowercased())
    }

    /// "18:50", "tmrw 05:00", "thu 05:00"
    static func resetClock(_ d: Date?, now: Date) -> String {
        guard let d = d else { return "—" }
        let cal = Calendar.current
        let time = d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        if cal.isDate(d, inSameDayAs: now) { return time }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(d, inSameDayAs: t) { return "tmrw " + time }
        return d.formatted(.dateTime.weekday(.abbreviated)).lowercased() + " " + time
    }

    static func span(_ s: TimeInterval) -> String {
        let m = Int(s / 60), h = m / 60, d = h / 24
        if d > 0 { return "\(d)d \(h % 24)h" }
        if h > 0 { return "\(h)h \(m % 60)m" }
        return "\(max(m, 1))m"
    }

    /// Projects current burn rate forward: returns the limit that will run dry before it resets, soonest first.
    static func pace(_ items: [LimitItem], now: Date) -> (LimitItem, TimeInterval)? {
        items.compactMap { item -> (LimitItem, TimeInterval)? in
            guard let reset = item.resetsAt else { return nil }
            let window: TimeInterval = item.title == "SESSION" ? 5 * 3600 : 7 * 86400
            let left = reset.timeIntervalSince(now)
            let elapsed = window - left
            guard elapsed > 600, item.used > 0, item.used < 100 else { return nil }
            let eta = (100 - item.used) / (item.used / elapsed)
            return eta < left ? (item, eta) : nil
        }
        .min { $0.1 < $1.1 }
    }
}

/// Background that hides the box border behind a label while matching the scanlined panel.
struct TermPatch: View {
    var body: some View { ZStack { TM.bg; Scanlines(spacing: 3).opacity(0.22) } }
}

struct TermBar: View, Animatable {
    var progress: Double
    let tint: Color
    var even: Double? = nil          // pace marker: where you'd be spending evenly
    var width: CGFloat = 150
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    var body: some View {
        Canvas { ctx, size in
            let top: CGFloat = 2, h: CGFloat = 9
            let filled = (size.width * progress).rounded()
            var dots = Path()
            var y: CGFloat = top, row = 0
            while y < top + h {
                var x: CGFloat = filled + 1.5 + CGFloat(row % 2) * 1.5
                while x < size.width { dots.addRect(CGRect(x: x, y: y, width: 1.5, height: 1.5)); x += 3 }
                y += 1.5; row += 1
            }
            ctx.fill(dots, with: .color(TM.dim.opacity(0.35)))
            ctx.fill(Path(CGRect(x: 0, y: top, width: filled, height: h)), with: .color(tint))
            ctx.fill(Path(CGRect(x: 0, y: top, width: filled, height: 1.5)), with: .color(.white.opacity(0.18)))
            if let e = even {
                let x = min(size.width - 1.5, max(0, (size.width * e).rounded()))
                ctx.fill(Path(CGRect(x: x - 0.75, y: 0, width: 1.5, height: size.height)), with: .color(TM.fg.opacity(0.85)))
            }
        }
        .frame(width: width, height: 13)
        .shadow(color: tint.opacity(0.3), radius: 3)
    }
}

/// Braille-style dot sparkline (drawn, so it never falls back to a wider font).
/// Each sample is a column of up to 4 dots; empty columns = no data yet.
struct Spark: View {
    let values: [Double?]
    let tint: Color
    static let dot: CGFloat = 2, step: CGFloat = 3.5

    var body: some View {
        let peak = max(values.compactMap { $0 }.max() ?? 0, 2)
        Canvas { ctx, size in
            for (i, v) in values.enumerated() {
                guard let v = v else { continue }
                let level = v <= 0 ? 1 : 1 + Int((v / peak * 3).rounded())
                let x = CGFloat(i) * Self.step + CGFloat(i / 2) * 1.5      // pair columns like braille cells
                for k in 0..<min(level, 4) {
                    let y = size.height - CGFloat(k + 1) * Self.step + (Self.step - Self.dot)
                    ctx.fill(Path(CGRect(x: x, y: y, width: Self.dot, height: Self.dot)),
                             with: .color(level == 1 ? TM.dim.opacity(0.6) : tint.opacity(0.8)))
                }
            }
        }
        .frame(width: CGFloat(values.count) * Self.step + CGFloat(values.count / 2) * 1.5, height: 4 * Self.step)
    }
}

struct TermRow: View {
    let item: LimitItem
    let now: Date
    let spark: [Double?]
    var animateIn = true
    var delay: Double = 0.15
    @State private var shown: Double = 0

    var body: some View {
        let tone = TM.tone(item.used)
        let (name, scope) = TM.label(item)
        let even = item.evenRemaining(now: now)
        HStack(spacing: 12) {
            Text(item.active ? "›" : " ").foregroundColor(tone).font(TM.font(12, .bold))
            (Text(name).foregroundColor(TM.fg) + Text(" " + scope).foregroundColor(TM.dim))
                .frame(width: 128, alignment: .leading)
            TermBar(progress: animateIn ? shown : item.remaining / 100, tint: tone, even: even)
                .help(paceHelp(even))
            (Text("\(Int(item.remaining.rounded()))%").foregroundColor(tone).font(TM.font(12, .bold))
             + Text(" left").foregroundColor(TM.dim))
                .frame(width: 72, alignment: .trailing)
            Spark(values: spark, tint: tone)
                .help(item.title == "SESSION" ? "Usage per 15 min, last 4 hours" : "Usage per 3 hours, last 2 days")
            (Text("resets ").foregroundColor(TM.dim) + Text(TM.resetClock(item.resetsAt, now: now)).foregroundColor(TM.fg.opacity(0.75)))
                .frame(width: 136, alignment: .leading)
                .fixedSize()
                .help(item.resetsAt.map { "Resets \($0.formatted(date: .abbreviated, time: .shortened)) · in \(TM.span($0.timeIntervalSince(now)))" } ?? "")
        }
        .font(TM.font(12))
        .fixedSize()
        .onAppear {
            guard animateIn else { return }
            withAnimation(.easeOut(duration: 0.7).delay(delay)) { shown = item.remaining / 100 }
        }
        .onChange(of: item.remaining) { _, v in withAnimation(.easeInOut(duration: 0.5)) { shown = v / 100 } }
    }

    func paceHelp(_ even: Double?) -> String {
        guard let e = even else { return "" }
        let diff = Int(((item.remaining / 100 - e) * 100).rounded())
        let verdict = diff >= 0 ? "\(diff) pts under even pace" : "\(-diff) pts over even pace"
        return "White tick = even pace (\(Int((e * 100).rounded()))% left if spread evenly). You're \(verdict)."
    }
}

// MARK: Clawd moods

enum ClawdMood { case idle, sweat, critical, sleep, party }

struct TermClawd: View {
    let mood: ClawdMood
    let t: Double
    var partyT: Double? = nil        // seconds since celebration started
    var hopT: Double? = nil          // seconds since clicked

    static let rows: [[Character]] = [
        "...############...",
        "...############...",
        ".################.",
        "...############...",
        "....#.#....#.#....",
    ].map(Array.init)
    static let p: CGFloat = 3

    var body: some View {
        let p = Self.p, h = p * 2
        let tick = Int(t * 2)
        let sitting = mood == .sleep || mood == .critical
        var dy: CGFloat = 0
        switch mood {
        case .idle: dy = (tick / 2) % 2 == 0 ? 0 : -1.5
        case .sweat: dy = tick % 2 == 0 ? 0 : -1.5
        case .party: dy = -CGFloat(abs(sin(t * 9))) * 7
        default: break
        }
        if let hop = hopT, hop < 0.4 { dy -= CGFloat(sin(hop / 0.4 * .pi)) * 9 }
        let body = mood == .critical ? (Int(t * 1.5) % 2 == 0 ? TM.amber : TM.red) : TM.amber
        let blink = mood == .idle && tick % 9 == 0

        return ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                let base: CGFloat = sitting ? h : 0
                for (y, row) in Self.rows.enumerated() where !(sitting && y == 4) {
                    for (x, c) in row.enumerated() where c == "#" {
                        ctx.fill(Path(CGRect(x: CGFloat(x) * p, y: base + CGFloat(y) * h, width: p + 0.3, height: h + 0.3)), with: .color(body))
                    }
                }
                // eyes
                for ex in [5, 12] {
                    let x = CGFloat(ex) * p, y = base + h
                    let r: CGRect
                    switch mood {
                    case .sleep: r = CGRect(x: x - p * 0.3, y: y + h * 0.55, width: p * 1.6, height: h * 0.22)
                    case .critical: r = CGRect(x: x, y: y + h * 0.45, width: p, height: h * 0.55)
                    case .party: r = CGRect(x: x, y: y, width: p, height: h * 0.45)
                    default: r = blink ? CGRect(x: x, y: y + h * 0.6, width: p, height: h * 0.25) : CGRect(x: x, y: y, width: p, height: h)
                    }
                    ctx.fill(Path(r), with: .color(TM.bg))
                }
            }
            .frame(width: p * 18, height: p * 10)
            .shadow(color: body.opacity(0.4), radius: 5)

            if mood == .sweat || mood == .critical {
                let phase = CGFloat(Int(t * 5) % 5)
                VStack(spacing: 0) {
                    Rectangle().frame(width: 1.5, height: 1.5)
                    Rectangle().frame(width: 3, height: 3)
                }
                .foregroundColor(PX.hex(0x8cc4e8))
                .offset(x: p * 16.5, y: (sitting ? h : 0) + phase * 2.5)
                .opacity(1 - Double(phase) / 6)
            }
            if mood == .sleep {
                ForEach(0..<2, id: \.self) { k in
                    let ph = (t * 0.5 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                    Text(k == 0 ? "z" : "Z")
                        .font(TM.font(k == 0 ? 9 : 11, .bold)).foregroundColor(TM.dim)
                        .offset(x: p * 15 + CGFloat(ph) * 8, y: -2 - CGFloat(ph) * 14)
                        .opacity(1 - ph)
                }
            }
            if mood == .party, let pt = partyT { Confetti(t: pt).offset(x: p * 9, y: p * 5) }
        }
        .offset(y: dy)
        .frame(width: p * 18, height: p * 10)
    }
}

struct Confetti: View {
    let t: Double
    static let bits: [(Double, Double, String, Color)] = (0..<14).map { i in
        let angle = -Double.pi / 2 + (Double(i) / 13 - 0.5) * 2.6
        let speed = 70 + Double((i * 37) % 30)
        let glyph = ["*", "+", "·", "✦", "•", "×"][i % 6]
        let color = [TM.amber, TM.yellow, TM.green, TM.fg, PX.hex(0x8cc4e8)][i % 5]
        return (angle, speed, glyph, color)
    }
    var body: some View {
        ZStack {
            ForEach(Array(Self.bits.enumerated()), id: \.offset) { _, b in
                let x = cos(b.0) * b.1 * t
                let y = sin(b.0) * b.1 * t + 90 * t * t
                Text(b.2).font(TM.font(11, .bold)).foregroundColor(b.3)
                    .offset(x: x, y: y)
                    .opacity(max(0, 1 - t / 2.4))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: Panel

struct TerminalPanel: View {
    @ObservedObject var model: QuotaModel
    var frozenTime: Date? = nil
    @State private var openedAt: Date?
    @State private var hopAt: Date?
    @State private var quip: (String, Date)?

    static let command = "claude usage --watch"
    static let bootTyping = 0.022        // seconds per character
    static var bootRows: Double { 0.15 + Double(command.count) * bootTyping }

    var body: some View {
        Group {
            if let d = frozenTime {
                content(t: d.timeIntervalSinceReferenceDate, now: d)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                    content(t: ctx.date.timeIntervalSinceReferenceDate, now: ctx.date)
                }
            }
        }
        .onAppear {
            guard frozenTime == nil else { return }
            openedAt = Date()
            consumeCelebration()
        }
        .onChange(of: model.pendingCelebration) { _, _ in consumeCelebration() }
    }

    func consumeCelebration() {
        guard let label = model.pendingCelebration else { return }
        model.pendingCelebration = nil
        model.celebration = Celebration(label: label, at: Date().addingTimeInterval(Self.bootRows))
    }

    func mood(now: Date) -> ClawdMood {
        if let c = model.celebration, now >= c.at, now.timeIntervalSince(c.at) < 3 { return .party }
        switch model.demo {
        case "sleep": return .sleep
        case "critical": return .critical
        case "sweat": return .sweat
        default: break
        }
        if model.items.contains(where: { $0.used >= 100 }) { return .sleep }
        let worst = model.items.map(\.used).max() ?? 0
        return worst >= 90 ? .critical : worst >= 70 ? .sweat : .idle
    }

    func quips(now: Date) -> [String] {
        let s = model.items.first { $0.title == "SESSION" }
        var q = [
            "tokens are a renewable resource. mostly.",
            "pro tip: /compact before the context gets chonky.",
            "psst. shift+tab cycles into plan mode.",
            "have you tried turning the prompt off and on again?",
            "ship it. (after the tests pass.)",
            "i'm not a crab. i'm not an octopus. i'm clawd.",
            "every limit resets eventually. so do i.",
            "hydrate. your context window too.",
        ]
        if let s = s {
            q.append("i run on vibes and \(Int(s.remaining.rounded()))% session.")
            q.append("session refills at \(TM.resetClock(s.resetsAt, now: now)). i'll wait.")
        }
        return q
    }

    func syncText(now: Date) -> String {
        if model.loading { return "syncing…" }
        guard let u = model.updatedAt else { return "offline" }
        let s = now.timeIntervalSince(u)
        return s < 45 ? "synced just now" : "synced \(TM.span(s)) ago"
    }

    func footer(now: Date, elapsed: Double, cursorOn: Bool) -> Text {
        let cursor = Text(cursorOn ? " ▌" : "  ").foregroundColor(TM.amber)
        if elapsed < Self.bootRows {
            let n = min(Self.command.count, max(0, Int((elapsed - 0.1) / Self.bootTyping)))
            return Text("$ ").foregroundColor(TM.amber) + Text(String(Self.command.prefix(n))).foregroundColor(TM.fg) + Text(" ▌").foregroundColor(TM.amber)
        }
        let prompt = Text("> ").foregroundColor(TM.amber)
        if let (q, at) = quip, now.timeIntervalSince(at) < 4 {
            return prompt + Text("clawd: ").foregroundColor(TM.amber) + Text("\"\(q)\"").foregroundColor(TM.fg) + cursor
        }
        if let c = model.celebration, now >= c.at, now.timeIntervalSince(c.at) < 3.5 {
            return prompt + Text("✦ \(c.label) ✦ ").foregroundColor(TM.yellow) + Text("go build something").foregroundColor(TM.fg) + cursor
        }
        if model.items.isEmpty { return prompt + Text("waiting for data").foregroundColor(TM.dim) + cursor }
        if let (item, eta) = TM.pace(model.items, now: now) {
            let (name, scope) = TM.label(item)
            let c = eta < 3600 ? TM.red : TM.yellow
            return prompt + Text("at this pace ").foregroundColor(TM.dim)
                + Text("\(name) \(scope)").foregroundColor(TM.fg)
                + Text(" runs out in ").foregroundColor(TM.dim)
                + Text("~" + TM.span(eta)).foregroundColor(c)
                + Text(", before it resets").foregroundColor(TM.dim) + cursor
        }
        if model.items.contains(where: { $0.used >= 100 }) {
            return prompt + Text("limit reached · clawd is napping until it resets").foregroundColor(TM.dim) + cursor
        }
        return prompt + Text("on pace").foregroundColor(TM.green) + Text(" · no limit will run out before it resets").foregroundColor(TM.dim) + cursor
    }

    func content(t: Double, now: Date) -> some View {
        let tick = Int(t * 2)
        let cursorOn = tick % 2 == 0
        let elapsed = frozenTime != nil ? 99 : now.timeIntervalSince(openedAt ?? now)
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous)
        let ok = model.error == nil
        let m = mood(now: now)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 18) {
                TermClawd(mood: m, t: t,
                          partyT: model.celebration.map { now.timeIntervalSince($0.at) },
                          hopT: hopAt.map { now.timeIntervalSince($0) })
                    .padding(.leading, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hopAt = Date()
                        quip = (quips(now: now).randomElement()!, Date())
                    }
                    .help("Poke Clawd")
                VStack(alignment: .leading, spacing: 8) {
                    if model.items.isEmpty {
                        Text(model.error.map { "✗ " + $0 } ?? "connecting to api.anthropic.com …")
                            .foregroundColor(ok ? TM.dim : TM.red).font(TM.font(12))
                            .frame(width: 640, alignment: .leading)
                    } else {
                        ForEach(Array(model.items.enumerated()), id: \.element.id) { i, item in
                            let revealAt = Self.bootRows + Double(i) * 0.09
                            TermRow(item: item, now: now, spark: model.spark(for: item, now: now),
                                    animateIn: frozenTime == nil, delay: revealAt)
                                .opacity(elapsed >= revealAt ? 1 : 0)
                        }
                    }
                }
            }
            .padding(.leading, 12).padding(.trailing, 14).padding(.top, 18).padding(.bottom, 14)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(TM.amber.opacity(0.45), lineWidth: 1))
            .overlay(alignment: .topLeading) {
                (Text(" ✻ ").foregroundColor(TM.amber) + Text("Quota Nook ").foregroundColor(TM.fg))
                    .font(TM.font(12, .semibold))
                    .background(TermPatch())
                    .offset(x: 14, y: -8)
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    let limited = model.error?.hasPrefix("Rate limited") == true
                    Circle().fill(ok ? TM.green : limited ? TM.yellow : TM.red).frame(width: 6, height: 6)
                        .opacity(model.loading ? (cursorOn ? 1 : 0.3) : 1)
                    Text(ok ? syncText(now: now) : (limited ? "retrying · " : "offline · ") + syncText(now: now))
                }
                .font(TM.font(11)).foregroundColor(TM.dim)
                .padding(.horizontal, 6)
                .background(TermPatch())
                .offset(x: -14, y: -8)
            }
            HStack(spacing: 0) {
                footer(now: now, elapsed: elapsed, cursorOn: cursorOn)
                Spacer(minLength: 16)
                Button { model.refresh() } label: {
                    Text("↻ refresh").foregroundColor(model.loading ? TM.dim : TM.amber)
                }
                .buttonStyle(.plain)
                .help("Refresh now")
            }
            .font(TM.font(11))
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 14)
        .padding(.top, max(model.topInset, 4) + 16)
        .padding(.bottom, 12)
        .background(ZStack { shape.fill(TM.bg); Scanlines(spacing: 3).opacity(0.22).clipShape(shape) })
        .overlay(shape.stroke(Color.white.opacity(0.06), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
    }
}

// MARK: - Island (minimal, Dynamic-Island-like)

enum IS {
    static let orange = PX.hex(0xe08a66)
    static let amber = PX.hex(0xf5b94f)
    static let red = PX.hex(0xff5f57)
    static func tone(_ used: Double) -> Color { used >= 90 ? red : used >= 70 ? amber : orange }
}

struct IslandItem: View {
    let item: LimitItem
    let now: Date
    var animateIn = true
    @State private var shown: Double = 0

    var body: some View {
        let tone = IS.tone(item.used)
        let name = item.title == "SESSION" ? "Session" : item.title == "WEEKLY" ? "Weekly" : item.title.capitalized
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                Circle().trim(from: 0, to: animateIn ? shown : item.remaining / 100)
                    .stroke(tone, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if item.active {
                    Circle().fill(tone).frame(width: 6, height: 6)
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(item.remaining.rounded()))")
                        .font(.system(size: 18, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white)
                    Text("%").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                }
                Text("\(name) · \(shortCountdown(item.resetsAt, now: now))")
                    .font(.system(size: 10.5, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                    .fixedSize()
            }
        }
        .fixedSize()
        .help(item.resetsAt.map { "\(name) resets \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")
        .onAppear {
            guard animateIn else { return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) { shown = item.remaining / 100 }
        }
        .onChange(of: item.remaining) { _, v in withAnimation(.easeInOut(duration: 0.5)) { shown = v / 100 } }
    }
}

struct IslandPanel: View {
    @ObservedObject var model: QuotaModel
    var frozenTime: Date? = nil

    var body: some View {
        if let d = frozenTime {
            content(now: d, t: d.timeIntervalSinceReferenceDate)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                content(now: ctx.date, t: ctx.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    func content(now: Date, t: Double) -> some View {
        HStack(spacing: 22) {
            Clawd(pixel: 1.7, color: IS.orange, eyesClosed: Int(t) % 5 == 0)
                .help(model.updatedAt.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? "")
            if model.items.isEmpty {
                Text(model.error ?? "Loading usage…")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: 360, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(model.items) { IslandItem(item: $0, now: now, animateIn: frozenTime == nil) }
            }
            Button { model.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(model.loading ? 0.25 : 0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.leading, 26).padding(.trailing, 16)
        .padding(.vertical, 14)
        .background(Capsule(style: .continuous).fill(Color.black))
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            if model.error != nil && !model.items.isEmpty {
                Circle().fill(IS.amber).frame(width: 6, height: 6).padding(.trailing, 20).padding(.bottom, 8)
                    .help("Last sync failed")
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.top, model.topInset + 6)
        .padding(.horizontal, 20).padding(.bottom, 24)
    }
}
