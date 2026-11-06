import SwiftUI
import WidgetKit

struct TrendEntry: TimelineEntry {
    let date: Date
    let top: [CandidateAverage]
    let updatedAt: Date?
    let isSilent: Bool
}

struct TrendProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrendEntry {
        TrendEntry(date: .now, top: [], updatedAt: nil, isSilent: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrendEntry) -> Void) {
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let next = Date().addingTimeInterval(6 * 3_600)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh(default: next))))
        }
    }

    /// Force un rafraîchissement à l'entrée et à la sortie de chaque silence électoral.
    private func nextRefresh(default fallback: Date) -> Date {
        let now = Date()
        let boundaries = ElectoralSilence.builtIn.flatMap { [$0.start, $0.end] }
        return boundaries.filter { $0 > now && $0 < fallback }.min() ?? fallback
    }

    private func makeEntry() async -> TrendEntry {
        let now = Date()
        let store = DataStore()
        var dataset = store.loadBest()
        if ElectoralSilence.isActive(at: now, remote: dataset.silencePeriods) {
            return TrendEntry(date: now, top: [], updatedAt: nil, isSilent: true)
        }
        if let remote = try? await store.fetchRemote() { dataset = remote }
        if ElectoralSilence.isActive(at: now, remote: dataset.silencePeriods) {
            return TrendEntry(date: now, top: [], updatedAt: nil, isSilent: true)
        }
        let result = AverageEngine().average(dataset: dataset, scope: .declared, at: now, includeTrend: false)
        return TrendEntry(date: now, top: Array(result.averages.prefix(3)), updatedAt: dataset.generatedAt, isSilent: false)
    }
}

struct TrendWidgetView: View {
    let entry: TrendEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppConfig.appName).font(.caption.bold()).foregroundStyle(Palette.accent)
            if entry.isSilent {
                Text("Silence électoral").font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            } else if entry.top.isEmpty {
                Text("Données insuffisantes").font(.subheadline)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.top) { item in
                    HStack {
                        Text(item.candidate.name).lineLimit(1).font(.caption)
                        Spacer(minLength: 4)
                        Text(Formatting.percent(item.displayed)).font(.caption.bold().monospacedDigit())
                    }
                }
                Spacer(minLength: 0)
                if let updated = entry.updatedAt {
                    Text("Maj \(updated.formatted(.dateTime.day().month()))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .containerBackground(Palette.sky.gradient, for: .widget)
    }
}

struct SondoscopeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SondoscopeTrend", provider: TrendProvider()) { entry in
            TrendWidgetView(entry: entry)
        }
        .configurationDisplayName("Tendance")
        .description("Top 3 de la moyenne des sondages.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SondoscopeWidgetBundle: WidgetBundle {
    var body: some Widget { SondoscopeWidget() }
}
