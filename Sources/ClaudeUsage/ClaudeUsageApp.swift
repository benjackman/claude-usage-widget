import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var model = UsageModel()
    @AppStorage("menuBarStyle") private var style: MenuBarStyle = .barsAndPercent

    var body: some Scene {
        MenuBarExtra {
            UsagePanel(model: model)
        } label: {
            if style == .text || model.session == nil {
                Text(menuTitle)
            } else {
                Image(nsImage: MenuBarBars.image(session: model.session?.percent ?? 0,
                                                 weekly: model.weekly?.percent ?? 0,
                                                 showPercent: style == .barsAndPercent))
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuTitle: String {
        guard let s = model.session else { return model.error == nil ? "✳︎ …" : "✳︎ !" }
        var title = "✳︎ \(Int(s.percent.rounded()))%"
        if let w = model.weekly { title += " · \(Int(w.percent.rounded()))%" }
        return title
    }
}

struct UsagePanel: View {
    @ObservedObject var model: UsageModel
    @AppStorage("menuBarStyle") private var style: MenuBarStyle = .barsAndPercent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude usage").font(.headline)

            ForEach(model.windows) { w in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(w.label)
                        Spacer()
                        Text("\(Int(w.percent.rounded()))%").monospacedDigit().bold()
                    }
                    ProgressView(value: min(w.percent, 100), total: 100)
                        .tint(color(for: w.percent))
                    if let r = w.resetsAt {
                        Text("Resets \(r.formatted(.relative(presentation: .named))) · \(r.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if let e = model.error {
                Text(e).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            Picker("Menu bar", selection: $style) {
                ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .font(.caption)

            HStack {
                if let t = model.lastUpdated {
                    Text("Updated \(t.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.loading ? "Refreshing…" : "Refresh") { Task { await model.refresh() } }
                    .disabled(model.loading)
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func color(for pct: Double) -> Color {
        pct >= 90 ? .red : pct >= 70 ? .orange : .accentColor
    }
}
