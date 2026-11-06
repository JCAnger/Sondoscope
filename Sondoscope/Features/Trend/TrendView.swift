import Charts
import SwiftUI

struct TrendView: View {
    @Environment(AppModel.self) private var model
    @State private var range = 90
    @State private var history: [HistoryPoint] = []

    private struct HistoryRequest: Hashable {
        let key: AppModel.ResultKey
        let range: Int
    }

    var body: some View {
        let result = model.result
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DemoBanner()
                header(result)
                if !model.excludedCandidateIDs.isEmpty { simulationCard }
                if model.phase == .loading {
                    ProgressView { Text("Chargement des sondages…") }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if result.hasEnoughData {
                    rankingCard(result, history: history)
                    if !history.isEmpty { chartCard(history) }
                    if !result.sparse.isEmpty { sparseCard(result) }
                } else {
                    insufficientCard(result)
                }
                DisclaimerLine()
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        // Historique calculé hors du thread principal, relancé si la période ou les entrées du calcul changent.
        .task(id: HistoryRequest(key: model.currentKey, range: range)) {
            history = result.hasEnoughData ? await model.loadHistory(days: range) : []
        }
        .refreshable { await model.refresh() }
        .navigationTitle("Tendance")
        .toolbar {
            ToolbarItem {
                Picker("Candidats suivis", selection: Bindable(model).scope) {
                    ForEach(CandidateScope.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem {
                Menu {
                    Toggle("Écarter retraits et candidatures uniques", isOn: Bindable(model).excludeReducedScenarios)
                    Menu("Supposer des retraits") {
                        ForEach(model.candidatesForDisplay) { candidate in
                            Toggle(candidate.name, isOn: Binding(
                                get: { model.isExcluded(candidate.id) },
                                set: { model.setExcluded(candidate.id, $0) }))
                        }
                    }
                    if !model.excludedCandidateIDs.isEmpty {
                        Button("Réinitialiser les retraits supposés", role: .destructive) {
                            model.excludedCandidateIDs = []
                        }
                    }
                } label: {
                    Label("Hypothèses", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    /// Rappelle en permanence que les résultats affichés sont une simulation de l'utilisateur.
    private var simulationCard: some View {
        let names = model.activeDataset.candidates
            .filter { model.excludedCandidateIDs.contains($0.id) }
            .map(\.name).sorted().formatted(.list(type: .and))
        return VStack(alignment: .leading, spacing: 6) {
            Label("Simulation : retrait supposé de \(names)", systemImage: "person.fill.xmark")
                .font(.subheadline.weight(.semibold))
            Text("Ces candidats sont retirés de la liste, et les hypothèses sans eux sont préférées. Les scores des autres ne sont pas redistribués. Ce n'est ni une prévision ni une recommandation.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Revenir aux résultats complets") { model.excludedCandidateIDs = [] }
                .font(.footnote)
        }
        .aquaCard()
    }

    private func header(_ result: AverageResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("1er tour").font(.title2.bold())
            Text("\(result.pollCount) sondage(s) pris en compte")
                .font(.subheadline).foregroundStyle(.secondary)
            if let generated = model.activeDataset.generatedAt {
                Text("Données mises à jour le \(Formatting.day(generated))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if model.lastRefreshFailed {
                Label("Hors ligne : dernières données disponibles affichées", systemImage: "wifi.slash")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func rankingCard(_ result: AverageResult, history: [HistoryPoint]) -> some View {
        let series = Dictionary(grouping: history, by: \.candidate.id)
            .mapValues { $0.sorted { $0.date < $1.date } }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Moyenne pondérée").font(.headline)
                InfoBubble(title: "Moyenne pondérée",
                           text: "Les sondages récents, les grands échantillons et la diversité des instituts comptent davantage.")
                Spacer()
                NavigationLink("Méthode") { MethodView() }.font(.subheadline)
            }
            let top = result.averages.first?.raw ?? 1
            ForEach(Array(result.averages.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    CandidateDetailView(candidate: item.candidate)
                } label: {
                    AverageRow(item: item, scale: max(top, 1), previous: index > 0 ? result.averages[index - 1] : nil,
                               history: series[item.candidate.id] ?? [])
                }
                .buttonStyle(.plain)
            }
        }
        .aquaCard()
    }

    private func chartCard(_ history: [HistoryPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Évolution").font(.headline)
            Picker("Période", selection: $range) {
                Text("30 j").tag(30)
                Text("90 j").tag(90)
                Text("Tout").tag(364)
            }
            .pickerStyle(.segmented)
            Chart(history) { point in
                LineMark(x: .value("Date", point.date),
                         y: .value("Intention de vote", point.value),
                         series: .value("Candidat", point.candidate.name))
                    .foregroundStyle(by: .value("Candidat", point.candidate.name))
                    .symbol(by: .value("Candidat", point.candidate.name))
                    .interpolationMethod(.monotone)
            }
            .chartYAxisLabel("%")
            .frame(height: 260)
            .accessibilityLabel("Courbes d'évolution des moyennes par candidat")
        }
        .aquaCard()
    }

    private func sparseCard(_ result: AverageResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Données insuffisantes").font(.headline)
            Text(result.sparse.map(\.name).joined(separator: ", "))
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .aquaCard()
    }

    private func insufficientCard(_ result: AverageResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Données insuffisantes", systemImage: "tray").font(.headline)
            Text("Il faut au moins 3 sondages récents pour calculer une moyenne.")
                .font(.subheadline).foregroundStyle(.secondary)
            #if DEBUG
            Toggle("Afficher des données fictives", isOn: Bindable(model).demoMode)
            #endif
        }
        .aquaCard()
    }
}

private struct AverageRow: View {
    let item: CandidateAverage
    let scale: Double
    let previous: CandidateAverage?
    /// Moyennes hebdomadaires de la période choisie, de la plus ancienne à la plus récente.
    let history: [HistoryPoint]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

    /// Évolution sur 30 jours si elle dépasse le seuil de tendance, sinon nil.
    private var movingTrend: Double? {
        guard let trend = item.trend, abs(trend) > AverageSettings().trendThreshold else { return nil }
        return trend
    }

    private var trendDescription: String {
        guard let trend = item.trend else { return "" }
        guard let moving = movingTrend else { return ", stable sur 30 jours" }
        return ", en \(moving > 0 ? "hausse" : "baisse") de \(Formatting.points(AverageEngine.roundHalf(abs(trend)))) sur 30 jours"
    }

    private var tiedWithPrevious: Bool {
        previous.map { AverageEngine.overlap($0, item) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Monogram(candidate: item.candidate, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.candidate.name).font(.subheadline.weight(.semibold))
                    if let party = item.candidate.party {
                        Text(party).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if history.count > 1 {
                    Chart(history) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Moyenne", point.value))
                            .foregroundStyle(Palette.color(for: item.candidate.id))
                            .interpolationMethod(.monotone)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    // Échelle propre à chaque ligne : on lit la forme de la courbe, pas le niveau.
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(width: 64, height: 28)
                    .accessibilityHidden(true)
                }
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 4) {
                        // Flèche neutre (couleur d'accent) : elle indique le sens, jamais un jugement.
                        if let moving = movingTrend {
                            Image(systemName: moving > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Palette.accent)
                                .accessibilityHidden(true)
                        }
                        Text(Formatting.percent(item.displayed))
                            .font(.headline.monospacedDigit())
                    }
                    Text("± \(Formatting.percent(item.displayedMargin))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    Capsule()
                        .fill(Palette.color(for: item.candidate.id))
                        .frame(width: proxy.size.width * (filled ? min(item.raw / scale, 1) : 0))
                }
            }
            .frame(height: 10)
            HStack {
                if let trend = item.trend {
                    if abs(trend) > AverageSettings().trendThreshold {
                        Label(Formatting.points(AverageEngine.roundHalf(trend)) + " sur 30 jours",
                              systemImage: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                    } else {
                        Label("Stable sur 30 jours", systemImage: "arrow.right")
                    }
                }
                Spacer()
                if tiedWithPrevious { Text("Écart non significatif") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onAppear {
            if reduceMotion { filled = true } else { withAnimation(.gentle) { filled = true } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.candidate.name), \(Formatting.percent(item.displayed)), plus ou moins \(Formatting.percent(item.displayedMargin))\(trendDescription)")
    }
}
