import Foundation

struct UsageWindow: Identifiable {
    let id: String
    let label: String
    let percent: Double
    let resetsAt: Date?
}

@MainActor
final class UsageModel: ObservableObject {
    @Published var windows: [UsageWindow] = []
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var loading = false
    /// Set while backing off after a 429; the panel shows it as a soft note, not an error.
    @Published var rateLimitedUntil: Date?

    private let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let pollInterval: TimeInterval = 300
    private var backoff: TimeInterval = 0
    private var nextPoll: Task<Void, Never>?

    private static let labels: [(key: String, label: String)] = [
        ("five_hour", "Session (5h)"),
        ("seven_day", "Weekly"),
        ("seven_day_opus", "Weekly · Opus"),
        ("seven_day_sonnet", "Weekly · Sonnet"),
    ]

    init() {
        Task { await refresh() }
    }

    private func schedule(after delay: TimeInterval) {
        nextPoll?.cancel()
        nextPoll = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    var session: UsageWindow? { windows.first { $0.id == "five_hour" } }
    var weekly: UsageWindow? { windows.first { $0.id == "seven_day" } }

    func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let token = try await Credentials.accessToken()
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            let http = resp as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            if status == 429 {
                // Back off exponentially (5 → 10 → 20 → 30 min cap), honouring Retry-After if sent.
                backoff = min(max(backoff * 2, pollInterval), 1800)
                let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                let delay = max(backoff, retryAfter ?? 0)
                rateLimitedUntil = Date().addingTimeInterval(delay)
                schedule(after: delay)
                return
            }
            guard status == 200 else {
                throw NSError(domain: "Usage", code: status, userInfo: [NSLocalizedDescriptionKey:
                    "HTTP \(status): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")"])
            }
            windows = try Self.parse(data)
            error = nil
            rateLimitedUntil = nil
            backoff = 0
            lastUpdated = Date()
        } catch {
            self.error = error.localizedDescription
        }
        schedule(after: pollInterval)
    }

    static func parse(_ data: Data) throws -> [UsageWindow] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        return labels.compactMap { key, label in
            guard let w = json[key] as? [String: Any],
                  let pct = (w["utilization"] as? NSNumber)?.doubleValue else { return nil }
            let reset = (w["resets_at"] as? String).flatMap { iso.date(from: $0) ?? isoPlain.date(from: $0) }
            return UsageWindow(id: key, label: label, percent: pct, resetsAt: reset)
        }
    }
}
