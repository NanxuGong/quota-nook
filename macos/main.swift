import Cocoa
import SwiftUI
import Combine

// MARK: - Data

struct LimitItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let used: Double          // percent used, 0–100
    let resetsAt: Date?
    let active: Bool          // the limit currently throttling you
    var remaining: Double { max(0, min(100, 100 - used)) }
    var key: String { title + ":" + subtitle }              // stable across fetches
    var window: TimeInterval { title == "SESSION" ? 5 * 3600 : 7 * 86400 }
    var displayName: String {
        title == "SESSION" ? "Session" : title == "WEEKLY" ? "Weekly (all models)" : "Weekly · " + title.capitalized
    }
    /// Fraction of quota you'd have left right now if you spent it evenly across the window.
    func evenRemaining(now: Date) -> Double? {
        guard let r = resetsAt else { return nil }
        return min(1, max(0, r.timeIntervalSince(now) / window))
    }
}

struct Sample: Codable { let t: Double; let u: Double }
struct Celebration: Equatable { let label: String; let at: Date }

private enum LocalUsageError: LocalizedError {
    case codexUnavailable
    case codexResponse(String)

    var errorDescription: String? {
        switch self {
        case .codexUnavailable:
            return "Codex CLI not found. Install or open the Codex app once."
        case .codexResponse(let message):
            return message
        }
    }
}

final class QuotaModel: ObservableObject {
    @Published var items: [LimitItem] = []
    @Published var error: String?
    @Published var updatedAt: Date?
    @Published var loading = false
    @Published var codexItems: [LimitItem] = []
    @Published var codexError: String?
    @Published var codexUpdatedAt: Date?
    @Published var codexLoading = false
    @Published var isOpen = false
    @Published var topInset: CGFloat = 0
    @Published var history: [String: [Sample]] = [:]
    @Published var pendingCelebration: String?        // a limit refilled; played next time Clawd is on screen
    @Published var celebration: Celebration?
    var demo: String? = ProcessInfo.processInfo.environment["CLAUDE_USAGE_DEMO"]
    @Published var scene: String = UserDefaults.standard.string(forKey: "scene") ?? "auto" {
        didSet { UserDefaults.standard.set(scene, forKey: "scene") }
    }
    @Published var theme: String = UserDefaults.standard.string(forKey: "theme") ?? "scenic" {
        didSet { UserDefaults.standard.set(theme, forKey: "theme") }
    }

    static let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("quota-nook-claude.json")
    static let codexCacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("quota-nook-codex.json")

    /// Show the last good result instantly (also survives rate limits / offline starts).
    func loadCache() {
        if let data = try? Data(contentsOf: Self.cacheURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            items = Self.parse(json)
            updatedAt = (try? FileManager.default.attributesOfItem(atPath: Self.cacheURL.path)[.modificationDate]) as? Date
        }
        if let data = try? Data(contentsOf: Self.codexCacheURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            codexItems = Self.parseCodex(json)
            codexUpdatedAt = (try? FileManager.default.attributesOfItem(atPath: Self.codexCacheURL.path)[.modificationDate]) as? Date
        }
    }

    static let supportDir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuotaNook")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static var historyURL: URL { supportDir.appendingPathComponent("history.json") }

    func loadHistory() {
        if let d = try? Data(contentsOf: Self.historyURL), let h = try? JSONDecoder().decode([String: [Sample]].self, from: d) {
            history = h
        }
    }

    private func record(_ items: [LimitItem]) {
        let now = Date().timeIntervalSince1970
        for item in items {
            var list = history[item.key] ?? []
            list.append(Sample(t: now, u: item.used))
            list.removeAll { now - $0.t > 8 * 86400 }
            history[item.key] = list
        }
        if let d = try? JSONEncoder().encode(history) { try? d.write(to: Self.historyURL) }
    }

    /// Usage consumed per bucket (percentage points), oldest first; nil where there is no data yet.
    func spark(for item: LimitItem, now: Date, buckets: Int = 16) -> [Double?] {
        let samples = history[item.key] ?? []
        let span: TimeInterval = item.title == "SESSION" ? 4 * 3600 : 48 * 3600
        let b = span / Double(buckets)
        let start = now.timeIntervalSince1970 - span
        func value(at t: Double) -> Double? { samples.last { $0.t <= t }?.u }
        return (0..<buckets).map { i in
            let s = start + Double(i) * b, e = s + b
            guard let ve = value(at: e), let vs = value(at: s) else { return nil }
            let d = ve - vs
            return d < 0 ? ve : d          // a reset happened inside the bucket
        }
    }

    func start() {
        loadHistory()
        loadCache()
        refresh()
        let t = Timer(timeInterval: 120, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
    }

    /// Fake history/events so renders can show features that need time to accumulate.
    func fillDemo() {
        let now = Date().timeIntervalSince1970
        for item in items {
            let base = max(0, item.used - (item.title == "SESSION" ? 30 : 25))
            let span: Double = item.title == "SESSION" ? 4 * 3600 : 48 * 3600
            let inc = (0..<96).map { i in Double((i * 7919) % 5) * (i % 13 < 7 ? 1 : 0.15) }
            let total = inc.reduce(0, +)
            var cum = 0.0, list: [Sample] = []
            for i in 0..<96 {
                cum += inc[i]
                list.append(Sample(t: now - span + Double(i) * span / 96, u: (base + (item.used - base) * cum / total).rounded()))
            }
            list.append(Sample(t: now, u: item.used))
            history[item.key] = list
        }
        if codexItems.isEmpty {
            codexItems = [
                LimitItem(id: "codex-session", title: "SESSION", subtitle: "5H WINDOW", used: 32,
                          resetsAt: Date().addingTimeInterval(2.7 * 3600), active: false),
                LimitItem(id: "codex-weekly", title: "WEEKLY", subtitle: "ALL MODELS", used: 49,
                          resetsAt: Date().addingTimeInterval(4.2 * 86400), active: false),
            ]
        }
        if demo == "party" { celebration = Celebration(label: "session refilled", at: Date().addingTimeInterval(-0.7)) }
    }

    func refreshIfStale() {
        let now = Date()
        if updatedAt == nil || now.timeIntervalSince(updatedAt!) >= 60 { refreshClaude() }
        if codexUpdatedAt == nil || now.timeIntervalSince(codexUpdatedAt!) >= 60 { refreshCodex() }
    }

    // Claude Code keeps its OAuth token in the login keychain; re-read it each time since it rotates.
    private func readToken() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let obj = try? JSONSerialization.jsonObject(with: out.fileHandleForReading.readDataToEndOfFile()) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any] else { return nil }
        return oauth["accessToken"] as? String
    }

    func refresh(completion: (() -> Void)? = nil) {
        refreshCodex()
        refreshClaude(completion: completion)
    }

    private func refreshClaude(completion: (() -> Void)? = nil) {
        guard !loading else { return }
        loading = true
        DispatchQueue.global().async {
            guard let token = self.readToken() else {
                return self.finish(nil, "Not signed in to Claude Code. Run `claude` in Terminal to log in.", completion)
            }
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            req.timeoutInterval = 20
            URLSession.shared.dataTask(with: req) { data, resp, err in
                if let err = err { return self.finish(nil, "Network error: \(err.localizedDescription)", completion) }
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 401 { return self.finish(nil, "Session expired. Open Claude Code once to refresh it.", completion) }
                if code == 429 {
                    let wait = Double((resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60
                    DispatchQueue.main.asyncAfter(deadline: .now() + min(max(wait, 5), 600) + 1) { self.refresh() }
                    return self.finish(nil, "Rate limited. Retrying in \(Int(wait))s.", completion)
                }
                guard code == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return self.finish(nil, "Request failed (HTTP \(code)).", completion)
                }
                try? data.write(to: Self.cacheURL)
                self.finish(Self.parse(json), nil, completion)
            }.resume()
        }
    }

    private func finish(_ items: [LimitItem]?, _ err: String?, _ completion: (() -> Void)?) {
        DispatchQueue.main.async {
            self.loading = false
            self.error = err
            if let items = items {
                self.items = items
                self.updatedAt = Date()
                self.record(items)
            }
            completion?()
        }
    }

    /// Codex exposes the account's short and weekly windows through its local app-server.
    /// Using the app-server keeps authentication inside Codex instead of reading token files here.
    private func refreshCodex() {
        guard !codexLoading else { return }
        codexLoading = true
        DispatchQueue.global(qos: .utility).async {
            do {
                let json = try Self.fetchCodexRateLimits()
                if JSONSerialization.isValidJSONObject(json),
                   let data = try? JSONSerialization.data(withJSONObject: json) {
                    try? data.write(to: Self.codexCacheURL, options: .atomic)
                }
                let parsed = Self.parseCodex(json)
                DispatchQueue.main.async {
                    self.codexLoading = false
                    self.codexError = parsed.isEmpty ? "Codex returned no usage windows." : nil
                    if !parsed.isEmpty {
                        self.codexItems = parsed
                        self.codexUpdatedAt = Date()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.codexLoading = false
                    self.codexError = error.localizedDescription
                }
            }
        }
    }

    private static func codexExecutable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let appRoots = ["/Applications/ChatGPT.app", "/Applications/Codex.app",
                        "\(home)/Applications/ChatGPT.app", "\(home)/Applications/Codex.app"]
        let bundled = appRoots.flatMap { root in
            ["\(root)/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
             "\(root)/Contents/Resources/codex"]
        }
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map { "\($0)/codex" }
        let candidates = [ProcessInfo.processInfo.environment["CODEX_CLI_PATH"]]
            .compactMap { $0 } + bundled + ["\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"] + pathEntries
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map(URL.init(fileURLWithPath:))
    }

    private static func fetchCodexRateLimits() throws -> [String: Any] {
        guard let executable = codexExecutable() else { throw LocalUsageError.codexUnavailable }

        let process = Process()
        let input = Pipe(), output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()

        let timeout = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 15, execute: timeout)
        defer {
            timeout.cancel()
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
        }

        let messages = [
            ["method": "initialize", "id": 0, "params": ["clientInfo": ["name": "quota_nook", "title": "Quota Nook", "version": "1.0.0"]]],
            ["method": "initialized", "params": [:]],
            ["method": "account/rateLimits/read", "id": 1],
        ] as [[String: Any]]
        for message in messages {
            let data = try JSONSerialization.data(withJSONObject: message)
            input.fileHandleForWriting.write(data + Data([0x0a]))
        }

        var buffered = Data()
        while process.isRunning {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            buffered.append(chunk)
            while let newline = buffered.firstIndex(of: 0x0a) {
                let line = buffered[..<newline]
                buffered.removeSubrange(...newline)
                guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      (message["id"] as? NSNumber)?.intValue == 1 else { continue }
                if let result = message["result"] as? [String: Any] { return result }
                let detail = ((message["error"] as? [String: Any])?["message"] as? String) ?? "Codex usage request failed."
                throw LocalUsageError.codexResponse(detail)
            }
        }
        throw LocalUsageError.codexResponse("Codex usage request timed out.")
    }

    static func date(_ s: Any?) -> Date? {
        guard let s = s as? String else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    static func parse(_ json: [String: Any]) -> [LimitItem] {
        if let limits = json["limits"] as? [[String: Any]], !limits.isEmpty {
            return limits.enumerated().map { i, l in
                let kind = l["kind"] as? String ?? ""
                let (title, subtitle): (String, String)
                switch kind {
                case "session": (title, subtitle) = ("SESSION", "5H WINDOW")
                case "weekly_all": (title, subtitle) = ("WEEKLY", "ALL MODELS")
                default:
                    let scope = l["scope"] as? [String: Any]
                    let model = (scope?["model"] as? [String: Any])?["display_name"] as? String
                    (title, subtitle) = ((model ?? kind).uppercased(), "WEEKLY")
                }
                return LimitItem(id: "\(i)-\(kind)", title: title, subtitle: subtitle,
                                 used: (l["percent"] as? NSNumber)?.doubleValue ?? 0,
                                 resetsAt: date(l["resets_at"]),
                                 active: l["is_active"] as? Bool ?? false)
            }
        }
        // Fallback for the older response shape
        var out: [LimitItem] = []
        for (key, title, sub) in [("five_hour", "SESSION", "5H WINDOW"), ("seven_day", "WEEKLY", "ALL MODELS"),
                                  ("seven_day_opus", "OPUS", "WEEKLY"), ("seven_day_sonnet", "SONNET", "WEEKLY")] {
            if let o = json[key] as? [String: Any], let u = (o["utilization"] as? NSNumber)?.doubleValue {
                out.append(LimitItem(id: key, title: title, subtitle: sub, used: u, resetsAt: date(o["resets_at"]), active: false))
            }
        }
        return out
    }

    static func parseCodex(_ json: [String: Any]) -> [LimitItem] {
        guard let limits = json["rateLimits"] as? [String: Any] else { return [] }
        let active = limits["rateLimitReachedType"] is String
        func item(_ key: String, _ title: String, _ subtitle: String) -> LimitItem? {
            guard let window = limits[key] as? [String: Any],
                  let used = (window["usedPercent"] as? NSNumber)?.doubleValue else { return nil }
            let reset = (window["resetsAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            return LimitItem(id: "codex-\(key)", title: title, subtitle: subtitle,
                             used: used, resetsAt: reset, active: active)
        }
        return [item("primary", "SESSION", "5H WINDOW"),
                item("secondary", "WEEKLY", "ALL MODELS")].compactMap { $0 }
    }
}

// MARK: - Style

enum HUD {
    static let bg = Color(red: 0.030, green: 0.035, blue: 0.050)
    static let orange = Color(red: 0.851, green: 0.467, blue: 0.341)   // Claude #D97757
    static let cyan = Color(red: 0.38, green: 0.90, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.30)
    static let red = Color(red: 1.0, green: 0.34, blue: 0.38)
    static func tint(_ used: Double) -> Color { used >= 90 ? red : used >= 70 ? amber : cyan }
    static func status(_ used: Double) -> String { used >= 90 ? "CRITICAL" : used >= 70 ? "WARNING" : "NOMINAL" }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

func tMinus(_ d: Date?, now: Date) -> String {
    guard let d = d else { return "T- --:--:--" }
    let s = max(0, Int(d.timeIntervalSince(now)))
    let days = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60, sec = s % 60
    let hms = String(format: "%02d:%02d:%02d", h, m, sec)
    return days > 0 ? "T-\(days)D \(hms)" : "T- \(hms)"
}

func polar(_ c: CGPoint, _ r: CGFloat, _ deg: Double) -> CGPoint {
    let a = CGFloat(deg * .pi / 180)
    return CGPoint(x: c.x + r * CoreGraphics.cos(a), y: c.y + r * CoreGraphics.sin(a))
}

/// Arc as a polyline (angles in degrees, y-down, increasing = clockwise on screen).
func arc(_ c: CGPoint, _ r: CGFloat, _ from: Double, _ to: Double) -> Path {
    var p = Path()
    let steps = max(2, Int(abs(to - from) / 3))
    for i in 0...steps {
        let pt = polar(c, r, from + (to - from) * Double(i) / Double(steps))
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    return p
}

// MARK: - Clawd (the Claude Code mascot), pixel-art

struct Clawd: View {
    var pixel: CGFloat
    var color: Color = HUD.orange
    var eyesClosed = false

    static let rows: [[Character]] = [
        "...############...",
        "...##.######.##...",
        ".################.",
        "...############...",
        "....#.#....#.#....",
    ].map(Array.init)

    var body: some View {
        Canvas { ctx, _ in
            let h = pixel * 2
            for (y, row) in Self.rows.enumerated() {
                for (x, c) in row.enumerated() where c == "#" || (eyesClosed && y == 1 && (x == 5 || x == 12)) {
                    ctx.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * h, width: pixel + 0.4, height: h + 0.4)),
                             with: .color(color))
                }
            }
        }
        .frame(width: pixel * 18, height: pixel * 10)
    }
}

struct Scanlines: View {
    var spacing: CGFloat = 3
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            var y: CGFloat = 0
            while y < size.height { p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += spacing }
            ctx.fill(p, with: .color(.black))
        }
    }
}

struct Beam: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + r.width * 0.28, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX - r.width * 0.28, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Clawd as a hologram floating above a projector pad.
struct HoloClawd: View {
    let t: Double
    let mood: Color

    var body: some View {
        let bob = sin(t * 2.1) * 3
        let blink = t.truncatingRemainder(dividingBy: 3.7) < 0.13
        let flicker = 0.88 + 0.12 * sin(t * 41) * sin(t * 17)
        ZStack {
            Beam()
                .fill(LinearGradient(colors: [HUD.orange.opacity(0), HUD.orange.opacity(0.28)], startPoint: .top, endPoint: .bottom))
                .frame(width: 118, height: 62)
                .offset(y: 30)
            // projector pad
            Ellipse().fill(HUD.orange.opacity(0.35)).frame(width: 70, height: 12).blur(radius: 6).offset(y: 62)
            Ellipse().stroke(HUD.orange.opacity(0.9), lineWidth: 1.2).frame(width: 74, height: 12).offset(y: 62)
            Ellipse().stroke(HUD.orange.opacity(0.35), lineWidth: 1).frame(width: 96, height: 18).offset(y: 63)
            // rotating tick on the pad
            Circle().fill(HUD.orange).frame(width: 3.5, height: 3.5)
                .offset(x: cos(t * 1.6) * 37, y: 62 + sin(t * 1.6) * 6)
                .opacity(sin(t * 1.6) > 0 ? 1 : 0.35)

            ZStack {
                Clawd(pixel: 5.6, eyesClosed: blink).blur(radius: 7).opacity(0.8)
                Clawd(pixel: 5.6, eyesClosed: blink)
                    .overlay(Scanlines(spacing: 3).opacity(0.18).mask(Clawd(pixel: 5.6, eyesClosed: blink)))
            }
            .opacity(flicker)
            .offset(y: -6 + bob)
        }
        .frame(width: 128, height: 150)
        .overlay(alignment: .top) {
            Rectangle().fill(mood.opacity(0.0)).frame(height: 0)   // layout anchor
        }
    }
}

// MARK: - Gauges

struct Gauge: View, Animatable {
    var progress: Double          // remaining, 0–1
    let tint: Color
    let t: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) / 2

            // outer tick bezel
            for i in 0..<72 {
                let major = i % 6 == 0
                var p = Path()
                p.move(to: polar(c, R - 1, Double(i) * 5))
                p.addLine(to: polar(c, R - (major ? 6 : 3), Double(i) * 5))
                ctx.stroke(p, with: .color(.white.opacity(major ? 0.28 : 0.10)), lineWidth: 1)
            }
            // counter-rotating scanner arcs
            let spin = t * 40
            for k in 0..<2 {
                let a = spin + Double(k) * 180
                ctx.stroke(arc(c, R - 10, a, a + 55), with: .color(tint.opacity(0.55)), lineWidth: 1.2)
            }
            ctx.stroke(arc(c, R - 13, -spin * 0.6, -spin * 0.6 + 30), with: .color(.white.opacity(0.18)), lineWidth: 1)

            // segmented 270° meter
            let N = 30, start = 135.0, sweep = 270.0
            let seg = sweep / Double(N)
            let r = R - 22
            let lit = progress * Double(N)
            var glow = Path()
            for i in 0..<N {
                let a0 = start + Double(i) * seg + 1.3
                let p = arc(c, r, a0, a0 + seg - 2.6)
                let f = min(max(lit - Double(i), 0), 1)
                if f > 0 {
                    ctx.stroke(p, with: .color(tint.opacity(0.35 + 0.65 * f)), lineWidth: 8)
                    glow.addPath(p)
                } else {
                    ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 8)
                }
            }
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 6))
                l.stroke(glow, with: .color(tint.opacity(0.9)), lineWidth: 8)
            }
            // needle tip marker
            if lit > 0 {
                let tip = start + sweep * progress
                var n = Path()
                n.move(to: polar(c, r - 9, tip)); n.addLine(to: polar(c, r + 9, tip))
                ctx.stroke(n, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
            }
            // inner ring
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r + 11, y: c.y - r + 11, width: (r - 11) * 2, height: (r - 11) * 2)),
                       with: .color(.white.opacity(0.07)), lineWidth: 1)
        }
    }
}

struct Chamfer: Shape {
    var cut: CGFloat = 10
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + cut, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut))
        p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + cut))
        p.closeSubpath()
        return p
    }
}

struct GaugeCard: View {
    let item: LimitItem
    let t: Double
    let now: Date
    var animateIn = true
    @State private var shown: Double = 0

    var body: some View {
        let tint = HUD.tint(item.used)
        let critical = item.used >= 90
        let pulse = critical ? 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 5)) : 1
        VStack(spacing: 10) {
            ZStack {
                Gauge(progress: animateIn ? shown : item.remaining / 100, tint: tint, t: t)
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(String(format: "%02d", Int(item.remaining.rounded())))
                            .font(.system(size: 27, weight: .bold, design: .monospaced))
                        Text("%").font(HUD.mono(11, .bold)).opacity(0.55)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: tint.opacity(0.8), radius: 8)
                    Text("REMAIN").font(HUD.mono(7.5, .semibold)).kerning(2).foregroundStyle(tint.opacity(0.8))
                }
                .offset(y: 2)
            }
            .frame(width: 112, height: 112)

            VStack(spacing: 3) {
                Text(item.title).font(HUD.mono(11.5, .bold)).kerning(1.6).foregroundStyle(.white)
                Text(item.subtitle).font(HUD.mono(8.5)).kerning(1.2).foregroundStyle(.white.opacity(0.4))
            }
            Text(tMinus(item.resetsAt, now: now))
                .font(HUD.mono(10.5, .semibold)).monospacedDigit()
                .foregroundStyle(tint.opacity(0.95))
                .help(item.resetsAt.map { "Resets \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "")
            Text(HUD.status(item.used))
                .font(HUD.mono(8, .bold)).kerning(1.6)
                .foregroundStyle(tint)
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .background(Rectangle().fill(tint.opacity(0.10)))
                .overlay(Rectangle().stroke(tint.opacity(0.55), lineWidth: 0.8))
                .opacity(pulse)
        }
        .frame(width: 128)
        .padding(.top, 12).padding(.bottom, 12)
        .background(Chamfer().fill(LinearGradient(colors: [tint.opacity(0.07), Color.white.opacity(0.015)],
                                                  startPoint: .top, endPoint: .bottom)))
        .overlay(Chamfer().stroke(item.active ? tint.opacity(0.6) : Color.white.opacity(0.09), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if item.active {
                Text("ACTIVE").font(HUD.mono(7, .bold)).kerning(1.2).foregroundStyle(HUD.bg)
                    .padding(.horizontal, 4).padding(.vertical, 1.5)
                    .background(tint)
                    .padding(6)
            }
        }
        .onAppear {
            guard animateIn else { return }
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { shown = item.remaining / 100 }
        }
        .onChange(of: item.remaining) { _, v in
            withAnimation(.easeInOut(duration: 0.6)) { shown = v / 100 }
        }
    }
}

// MARK: - Panel chrome

struct GridBackdrop: View {
    var body: some View {
        Canvas { ctx, size in
            var g = Path()
            var x: CGFloat = 0
            while x < size.width { g.move(to: CGPoint(x: x, y: 0)); g.addLine(to: CGPoint(x: x, y: size.height)); x += 18 }
            var y: CGFloat = 0
            while y < size.height { g.move(to: CGPoint(x: 0, y: y)); g.addLine(to: CGPoint(x: size.width, y: y)); y += 18 }
            ctx.stroke(g, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
            var dots = Path()
            x = 0
            while x < size.width {
                y = 0
                while y < size.height { dots.addRect(CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)); y += 54 }
                x += 54
            }
            ctx.fill(dots, with: .color(HUD.orange.opacity(0.25)))
        }
    }
}

struct CornerBrackets: View {
    var top: CGFloat
    var body: some View {
        Canvas { ctx, s in
            let L: CGFloat = 12, i: CGFloat = 9
            let corners: [(CGPoint, CGFloat, CGFloat)] = [
                (CGPoint(x: i, y: top), 1, 1), (CGPoint(x: s.width - i, y: top), -1, 1),
                (CGPoint(x: i + 6, y: s.height - i - 6), 1, -1), (CGPoint(x: s.width - i - 6, y: s.height - i - 6), -1, -1),
            ]
            for (p, dx, dy) in corners {
                var b = Path()
                b.move(to: CGPoint(x: p.x + dx * L, y: p.y)); b.addLine(to: p); b.addLine(to: CGPoint(x: p.x, y: p.y + dy * L))
                ctx.stroke(b, with: .color(HUD.orange.opacity(0.7)), lineWidth: 1.2)
            }
        }
        .allowsHitTesting(false)
    }
}

struct Panel: View {
    @ObservedObject var model: QuotaModel
    var actions: AppDelegate?
    var frozenTime: Date? = nil       // for static rendering
    @State private var sweep: CGFloat = -0.15

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
    }

    var worst: LimitItem? { model.items.max { $0.used < $1.used } }

    func content(t: Double, now: Date) -> some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous)
        let topPad = max(model.topInset, 4) + 14
        return VStack(alignment: .leading, spacing: 14) {
            header(t: t)
            Rectangle()
                .fill(LinearGradient(colors: [HUD.orange.opacity(0), HUD.orange.opacity(0.5), HUD.orange.opacity(0)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
            HStack(alignment: .center, spacing: 12) {
                hero(t: t)
                if model.items.isEmpty {
                    placeholder(t: t)
                } else {
                    ForEach(model.items) { GaugeCard(item: $0, t: t, now: now, animateIn: frozenTime == nil) }
                }
            }
            footer(t: t, now: now)
        }
        .padding(.horizontal, 22)
        .padding(.top, topPad)
        .padding(.bottom, 16)
        .background(
            ZStack {
                shape.fill(HUD.bg)
                RadialGradient(colors: [HUD.orange.opacity(0.20), .clear], center: .top, startRadius: 0, endRadius: 320)
                RadialGradient(colors: [HUD.cyan.opacity(0.06), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 300)
                GridBackdrop()
                Scanlines(spacing: 3).opacity(0.22)
            }
            .clipShape(shape)
        )
        .overlay(CornerBrackets(top: topPad - 6))
        .overlay(
            GeometryReader { g in
                LinearGradient(colors: [.clear, HUD.orange.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 50)
                    .offset(y: sweep * g.size.height - 25)
                    .opacity(sweep > 1.05 || sweep < -0.1 ? 0 : 1)
            }
            .clipShape(shape)
            .allowsHitTesting(false)
        )
        .overlay(shape.stroke(LinearGradient(colors: [HUD.orange.opacity(0.55), Color.white.opacity(0.06)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .compositingGroup()
        .shadow(color: HUD.orange.opacity(0.18), radius: 30, y: 6)
        .shadow(color: .black.opacity(0.55), radius: 20, y: 12)
        .onAppear {
            guard frozenTime == nil else { return }
            withAnimation(.easeInOut(duration: 0.8)) { sweep = 1.15 }
        }
    }

    func header(t: Double) -> some View {
        let ok = model.error == nil
        let dot = ok ? HUD.cyan : HUD.amber
        return HStack(spacing: 10) {
            Clawd(pixel: 1.4).shadow(color: HUD.orange, radius: 4)
            HStack(spacing: 6) {
                Text("CLAUDE").font(HUD.mono(13, .heavy)).kerning(3).foregroundStyle(.white)
                Text("// USAGE TELEMETRY").font(HUD.mono(10, .medium)).kerning(1).foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 30)
            HStack(spacing: 5) {
                Circle().fill(dot).frame(width: 5, height: 5)
                    .shadow(color: dot, radius: 4)
                    .opacity(0.4 + 0.6 * (0.5 + 0.5 * sin(t * 4)))
                Text(model.loading ? "SYNCING" : ok ? "LINK OK" : "LINK LOST")
                    .font(HUD.mono(9, .bold)).kerning(1.2).foregroundStyle(dot)
            }
            Text("SYNC " + (model.updatedAt.map { $0.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)) } ?? "--:--:--"))
                .font(HUD.mono(9)).foregroundStyle(.white.opacity(0.4))
            Button { model.refresh() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(HUD.orange)
                    .rotationEffect(.degrees(model.loading ? t * 360 : 0))
                    .frame(width: 24, height: 20)
                    .background(Chamfer(cut: 5).fill(HUD.orange.opacity(0.10)))
                    .overlay(Chamfer(cut: 5).stroke(HUD.orange.opacity(0.5), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
    }

    func hero(t: Double) -> some View {
        let used = worst?.used ?? 0
        let mood = model.items.isEmpty ? HUD.amber : HUD.tint(used)
        let line = model.items.isEmpty ? "STANDBY" : used >= 90 ? "RUNNING HOT" : used >= 70 ? "PACE YOURSELF" : "ALL CLEAR"
        return VStack(spacing: 6) {
            HoloClawd(t: t, mood: mood)
            Text("UNIT CLAWD-01").font(HUD.mono(8.5, .bold)).kerning(1.4).foregroundStyle(.white.opacity(0.55))
            Text(line).font(HUD.mono(9.5, .heavy)).kerning(1.4).foregroundStyle(mood)
                .shadow(color: mood.opacity(0.7), radius: 5)
        }
        .frame(width: 132)
    }

    func placeholder(t: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.error == nil ? "ACQUIRING SIGNAL" + String(repeating: ".", count: Int(t * 3) % 4) : "SIGNAL LOST")
                .font(HUD.mono(13, .heavy)).kerning(2)
                .foregroundStyle(model.error == nil ? HUD.cyan : HUD.amber)
            if let e = model.error {
                Text(e).font(HUD.mono(10.5)).foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 300, alignment: .leading)
    }

    func footer(t: Double, now: Date) -> some View {
        HStack(spacing: 0) {
            Text("5H SESSION · 7D ROLLING · AUTO-SYNC 120S")
            Spacer(minLength: 20)
            Text(model.error.map { _ in "⚠ LAST SYNC FAILED" } ?? "HOVER TOP EDGE TO SUMMON")
                .foregroundStyle(model.error == nil ? .white.opacity(0.3) : HUD.amber)
        }
        .font(HUD.mono(8.5)).kerning(1).foregroundStyle(.white.opacity(0.3))
    }
}

/// Picks the style chosen in the right-click menu.
struct ThemedPanel: View {
    @ObservedObject var model: QuotaModel
    var actions: AppDelegate?
    var frozenTime: Date? = nil

    var body: some View {
        Group {
            switch model.theme {
            case "hud": Panel(model: model, actions: actions, frozenTime: frozenTime)
            case "terminal": TerminalPanel(model: model, frozenTime: frozenTime)
            case "island": IslandPanel(model: model, frozenTime: frozenTime)
            case "pixelscifi": NeonPixelPanel(model: model, frozenTime: frozenTime)
            case "scenic": ScenicPanel(model: model, actions: actions, frozenTime: frozenTime)
            default: PixelPanel(model: model, frozenTime: frozenTime)
            }
        }
        .contextMenu {
            if let a = actions {
                Button("Refresh Now") { model.refresh() }
                if model.theme == "scenic" {
                    Picker("Scene", selection: $model.scene) {
                        Text("Auto (by time of day)").tag("auto")
                        Text("Morning").tag("morning")
                        Text("Afternoon").tag("afternoon")
                        Text("Evening").tag("evening")
                    }
                }
                Picker("Style", selection: $model.theme) {
                    Text("Scenic").tag("scenic")
                    Text("Pixel Sci-Fi").tag("pixelscifi")
                    Text("Pixel").tag("pixel")
                    Text("Terminal").tag("terminal")
                    Text("Island").tag("island")
                    Text("Sci-Fi HUD").tag("hud")
                }
                Toggle("Launch at Login", isOn: Binding(get: { a.loginEnabled }, set: { a.setLogin($0) }))
                Divider()
                Button("Quit Quota Nook") { NSApp.terminate(nil) }
            }
        }
    }
}

struct Root: View {
    @ObservedObject var model: QuotaModel
    let actions: AppDelegate

    var body: some View {
        VStack(spacing: 0) {
            if model.isOpen {
                ThemedPanel(model: model, actions: actions)
                    .fixedSize()
                    .transition(model.theme == "hud" || model.theme == "island" || model.theme == "scenic"
                        ? .asymmetric(insertion: .scale(scale: 0.2, anchor: .top).combined(with: .opacity),
                                      removal: .scale(scale: 0.7, anchor: .top).combined(with: .opacity))
                        : .move(edge: .top))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Window & hot edge

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = QuotaModel()
    var window: NSPanel!
    var host: NSHostingView<Root>!
    var openScreen: NSScreen?
    var hoverStart: Date?
    var leaveStart: Date?
    var holdOpenUntil: Date?
    var armed = true                    // must leave the top edge before it can trigger again
    var pointer: () -> NSPoint = { NSEvent.mouseLocation }
    var onTransition: ((Bool) -> Void)?

    static let windowSize = NSSize(width: 900, height: 480)   // room for the panel + glow
    static let triggerDwell = 0.15       // seconds the pointer must rest at the top edge
    static let triggerWidth = 0.30       // centered fraction of screen width that acts as the hot zone
    static let closeDelay = 0.35

    func applicationDidFinishLaunching(_ n: Notification) {
        let env = ProcessInfo.processInfo.environment
        if let out = env["CLAUDE_USAGE_RENDER"] { return renderSnapshot(to: out) }

        window = NSPanel(contentRect: NSRect(origin: .zero, size: Self.windowSize),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        host = NSHostingView(rootView: Root(model: model, actions: self))
        host.sizingOptions = []          // never let SwiftUI resize the window
        window.contentView = host

        model.start()
        let poll = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(poll, forMode: .default)

        if env["CLAUDE_USAGE_SELFTEST"] != nil { return selfTest() }

        // Peek once on launch so you know it's running.
        if let s = NSScreen.main {
            holdOpenUntil = Date().addingTimeInterval(3)
            show(on: s)
            armed = false
        }
    }

    func screen(at p: NSPoint) -> NSScreen? {
        NSScreen.screens.first { p.x >= $0.frame.minX && p.x <= $0.frame.maxX && p.y >= $0.frame.minY && p.y <= $0.frame.maxY }
    }

    /// Area that keeps the panel open: the panel itself (measured from the live view, with a sane
    /// fallback while it is still animating in) plus a margin.
    var keepOpenRect: NSRect {
        var size = host.subviews.isEmpty ? .zero : host.fittingSize
        if let panelView = host.subviews.first { size = panelView.frame.size }
        let f = window.frame
        let measured = Self.panelSize
        let w = max(size.width > 50 && size.width < f.width ? size.width : 0, measured.width)
        let h = max(size.height > 50 && size.height < f.height ? size.height : 0, measured.height)
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h).insetBy(dx: -24, dy: -24)
    }
    static var panelSize = NSSize(width: 640, height: 300)

    func poll() {
        let p = pointer()
        let now = Date()
        guard let screen = screen(at: p) else { return }
        let f = screen.frame
        let atTopEdge = p.y >= f.maxY - 3
        let inHotZone = atTopEdge && abs(p.x - f.midX) <= f.width * Self.triggerWidth / 2

        if !model.isOpen {
            if !atTopEdge { armed = true }
            if inHotZone && armed {
                if hoverStart == nil { hoverStart = now }
                else if now.timeIntervalSince(hoverStart!) >= Self.triggerDwell {
                    hoverStart = nil
                    armed = false
                    show(on: screen)
                }
            } else {
                hoverStart = nil
            }
            return
        }

        if let hold = holdOpenUntil, now < hold { return }
        holdOpenUntil = nil
        let inside = keepOpenRect.contains(p) || (inHotZone && screen == openScreen)
        if inside {
            leaveStart = nil
        } else if leaveStart == nil {
            leaveStart = now
        } else if now.timeIntervalSince(leaveStart!) > Self.closeDelay {
            hide()
        }
    }

    func show(on screen: NSScreen) {
        let f = screen.frame
        openScreen = screen
        window.setFrame(NSRect(x: f.midX - Self.windowSize.width / 2, y: f.maxY - Self.windowSize.height,
                               width: Self.windowSize.width, height: Self.windowSize.height), display: false)
        model.topInset = screen.safeAreaInsets.top
        leaveStart = nil
        window.ignoresMouseEvents = false
        window.orderFrontRegardless()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { model.isOpen = true }
        model.refreshIfStale()
        onTransition?(true)
        // learn the real panel size once it has laid out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.measurePanel() }
    }

    func measurePanel() {
        let size = NSHostingView(rootView: ThemedPanel(model: model, frozenTime: Date()).fixedSize()).fittingSize
        if size.width > 100, size.height > 100 { Self.panelSize = size }
    }

    func hide() {
        leaveStart = nil
        window.ignoresMouseEvents = true
        withAnimation(.easeIn(duration: 0.18)) { model.isOpen = false }
        onTransition?(false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, !self.model.isOpen else { return }
            self.window.orderOut(nil)
        }
    }

    // MARK: Dev helpers

    /// Drives a fake pointer through open → hover → leave → re-open and logs every transition.
    func selfTest() {
        let t0 = Date()
        let s = NSScreen.main!.frame
        let top = NSPoint(x: s.midX + 40, y: s.maxY - 1)
        pointer = {
            let e = Date().timeIntervalSince(t0)
            switch e {
            case ..<1: return NSPoint(x: s.midX, y: s.midY)                  // idle
            case ..<4: return top                                           // rest on top edge → open, stay open
            case ..<6: return NSPoint(x: s.midX - 150, y: s.maxY - 160)     // inside the panel → stay open
            case ..<8: return NSPoint(x: s.minX + 50, y: s.minY + 50)       // far away → close
            case ..<10: return top                                          // back to the top → open again
            default: return NSPoint(x: s.midX, y: s.midY)
            }
        }
        onTransition = { open in
            print(String(format: "%5.2fs %@", Date().timeIntervalSince(t0), open ? "OPEN" : "CLOSE")); fflush(stdout)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 11) {
            print("panel size \(Self.panelSize)"); fflush(stdout)
            NSApp.terminate(nil)
        }
    }

    @MainActor func renderSnapshot(to path: String) {
        let draw = { [self] in
            if let th = ProcessInfo.processInfo.environment["CLAUDE_USAGE_THEME"] { self.model.theme = th }
            let view = ThemedPanel(model: self.model, frozenTime: Date()).fixedSize().padding(40).background(Color(white: 0.55))
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
            NSApp.terminate(nil)
        }
        if model.demo != nil {
            model.fillDemo()
            draw()
        } else {
            model.loadCache()
            model.loadHistory()
            model.refresh { MainActor.assumeIsolated { draw() } }
        }
    }

    // MARK: Launch at login (per-user LaunchAgent)

    let agentLabel = "local.quota-nook"
    var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }
    var loginEnabled: Bool { FileManager.default.fileExists(atPath: agentURL.path) }
    func setLogin(_ on: Bool) {
        if on {
            let plist: [String: Any] = ["Label": agentLabel,
                                        "ProgramArguments": ["/usr/bin/open", Bundle.main.bundlePath],
                                        "RunAtLoad": true]
            try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            (plist as NSDictionary).write(to: agentURL, atomically: true)
        } else {
            try? FileManager.default.removeItem(at: agentURL)
        }
        model.objectWillChange.send()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
