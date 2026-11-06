import Charts
import SwiftUI

struct TrendView: View {
    @Environment(AppModel.self) private var model
    @State private var range = 90

    var body: some View {
        let result = model.result

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DemoBanner()
                header(result)
                if result.hasEnoughData {
                    rankingCard(result)
                    chartCard
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
        .refreshable { await model.refresh() }
        .navigationTitle("Tendance")
        .toolbar {
            ToolbarItem {
                Picker("Candidats suivis", selection: Bindable(model).scope) {
                    ForEach(CandidateScope.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
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

    private func rankingCard(_ result: AverageResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    AverageRow(item: item, scale: max(top, 1), previous: index > 0 ? result.averages[index - 1] : nil)
                }
                .buttonStyle(.plain)
            }
        }
        .aquaCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Évolution").font(.headline)
            Picker("Période", selection: $range) {
                Text("30 j").tag(30)
                Text("90 j").tag(90)
                Text("Tout").tag(364)
            }
            .pickerStyle(.segmented)
            Chart(model.history(days: range)) { point in
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

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
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Formatting.percent(item.displayed))
                        .font(.headline.monospacedDigit())
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
                if let trend = item.trend, abs(trend) > 1 {
                    Label(Formatting.points(AverageEngine.roundHalf(trend)) + " sur 30 jours",
                          systemImage: trend > 0 ? "arrow.up.right" : "arrow.down.right")
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
        .accessibilityLabel("\(item.candidate.name), \(Formatting.percent(item.displayed)), plus ou moins \(Formatting.percent(item.displayedMargin))")
    }
}
