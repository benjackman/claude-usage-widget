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

    private let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private var timer: Timer?

    private static let labels: [(key: String, label: String)] = [
        ("five_hour", "Session (5h)"),
        ("seven_day", "Weekly"),
        ("seven_day_opus", "Weekly · Opus"),
        ("seven_day_sonnet", "Weekly · Sonnet"),
    ]

    init() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    var session: UsageWindow? { windows.first { $0.id == "five_hour" } }
    var weekly: UsageWindow? { windows.first { $0.id == "seven_day" } }

    func refresh() async {
        loading = true
        defer { loading = false }
        do {
            let token = try await Credentials.accessToken()
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                throw NSError(domain: "Usage", code: status, userInfo: [NSLocalizedDescriptionKey:
                    "HTTP \(status): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")"])
            }
            windows = try Self.parse(data)
            error = nil
            lastUpdated = Date()
        } catch {
            self.error = error.localizedDescription
        }
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
