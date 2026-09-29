import Foundation

/// Reads and refreshes the Claude Code OAuth token stored in the login keychain.
/// Goes through /usr/bin/security (the same tool Claude Code uses to write the item),
/// so reads don't trigger a keychain access prompt for this app.
enum Credentials {
    static let service = "Claude Code-credentials"
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!

    enum Failure: LocalizedError {
        case notLoggedIn, malformed, refreshFailed(String)
        var errorDescription: String? {
            switch self {
            case .notLoggedIn: return "Not logged in — run `claude` and /login"
            case .malformed: return "Unrecognised credentials format"
            case .refreshFailed(let m): return "Token refresh failed: \(m)"
            }
        }
    }

    /// Returns a valid access token, refreshing (and writing back) if it has expired.
    static func accessToken() async throws -> String {
        var root = try readRoot()
        guard var oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { throw Failure.malformed }

        let expiresAt = (oauth["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        if let expiresAt, expiresAt > Date().addingTimeInterval(60) { return token }
        guard let refresh = oauth["refreshToken"] as? String else { return token }

        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token", "refresh_token": refresh, "client_id": clientID,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else {
            throw Failure.refreshFailed(String(data: data, encoding: .utf8)?.prefix(200).description ?? "")
        }
        // Refresh tokens rotate, so persist the new pair or Claude Code would be logged out.
        oauth["accessToken"] = newToken
        if let r = json["refresh_token"] as? String { oauth["refreshToken"] = r }
        if let secs = json["expires_in"] as? Double {
            oauth["expiresAt"] = (Date().timeIntervalSince1970 + secs) * 1000
        }
        root["claudeAiOauth"] = oauth
        try writeRoot(root)
        return newToken
    }

    private static func readRoot() throws -> [String: Any] {
        let out = try run(["find-generic-password", "-s", service, "-w"])
        guard out.status == 0 else { throw Failure.notLoggedIn }
        guard let data = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.malformed }
        return root
    }

    private static func writeRoot(_ root: [String: Any]) throws {
        let attrs = try run(["find-generic-password", "-s", service])
        let account = attrs.stdout.components(separatedBy: "\n")
            .first { $0.contains("\"acct\"") }
            .flatMap { $0.components(separatedBy: "=").last }?
            .trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            ?? NSUserName()
        let json = String(data: try JSONSerialization.data(withJSONObject: root), encoding: .utf8)!
        _ = try run(["add-generic-password", "-U", "-a", account, "-s", service, "-w", json])
    }

    private static func run(_ args: [String]) throws -> (status: Int32, stdout: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
