import Charts
import SwiftUI

struct CandidatesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                DemoBanner()
                Text("Une candidature annoncée n'est pas une candidature validée. La liste officielle du Conseil constitutionnel est attendue vers la mi-mars 2027.")
                    .font(.footnote).foregroundStyle(.secondary)
                if model.candidatesForDisplay.isEmpty {
                    ContentUnavailableView("Aucune candidature", systemImage: "person.2",
                                           description: Text("Les données ne sont pas encore disponibles."))
                }
                ForEach(model.candidatesForDisplay) { candidate in
                    NavigationLink {
                        CandidateDetailView(candidate: candidate)
                    } label: {
                        HStack(spacing: 12) {
                            Monogram(candidate: candidate)
                            VStack(alignment: .leading) {
                                Text(candidate.name).font(.headline)
                                Text(candidate.party ?? "Sans étiquette précisée")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(candidate.status.label).font(.caption).foregroundStyle(.secondary)
                        }
                        .aquaCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Candidats")
    }
}

struct CandidateDetailView: View {
    @Environment(AppModel.self) private var model
    let candidate: Candidate

    private var points: [HistoryPoint] {
        model.history(days: 364).filter { $0.candidate.id == candidate.id }
    }

    private struct LatestScore: Identifiable {
        let poll: Poll
        let percent: Double
        var id: String { poll.id }
    }

    private var latestScores: [LatestScore] {
        let rows = model.pollsNewestFirst.compactMap { poll -> LatestScore? in
            let values = poll.firstRoundHypotheses.flatMap(\.scores)
                .filter { $0.candidateID == candidate.id }.map(\.percent)
            guard let first = values.first else { return nil }
            return LatestScore(poll: poll, percent: first)
        }
        return Array(rows.prefix(8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Monogram(candidate: candidate, size: 60)
                    VStack(alignment: .leading) {
                        Text(candidate.name).font(.title2.bold())
                        if let party = candidate.party { Text(party).foregroundStyle(.secondary) }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Statut : \(candidate.status.label)").font(.headline)
                    if let detail = candidate.detail { Text(detail).font(.subheadline) }
                    if let checked = candidate.checkedOn {
                        Text("Vérifié le \(Formatting.day(checked))").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let url = candidate.sourceURL { Link("Voir la source", destination: url) }
                }
                .aquaCard()

                if points.count > 1 {
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Moyenne", point.value))
                            .foregroundStyle(Palette.color(for: candidate.id))
                            .interpolationMethod(.monotone)
                    }
                    .chartYAxisLabel("%")
                    .frame(height: 200)
                    .aquaCard()
                }

                if !latestScores.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Derniers scores").font(.headline)
                        ForEach(latestScores) { row in
                            HStack {
                                Text(row.poll.institute)
                                Spacer()
                                Text(Formatting.percent(row.percent)).monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                        Text("Première hypothèse publiée pour chaque sondage.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .aquaCard()
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(candidate.name)
    }
}
