import Foundation

struct AverageSettings: Hashable {
    var windowDays: Double = 60
    var halfLifeDays: Double = 7
    var maxSampleFactor: Double = 1.5
    var instituteDecay: Double = 0.5
    var minimumPolls: Int = 3
    var minimumMargin: Double = 1
    var trendThreshold: Double = 1
    var trendDays: Double = 30
    /// Écarte les hypothèses où un candidat suivi, testé dans une autre hypothèse du même sondage, est absent
    /// (retrait ou candidature unique d'un camp). Aucun sondage n'est écarté : sans hypothèse complète,
    /// on garde les plus larges.
    var excludeReducedScenarios = true
    /// Candidats que l'utilisateur suppose retirés : ils sortent de la liste suivie, donc des moyennes, et les
    /// hypothèses qui ne les contiennent pas sont préférées. Les scores des autres ne sont jamais redistribués.
    var excludedCandidateIDs: Set<String> = []
}

enum CandidateScope: String, CaseIterable, Identifiable {
    case declared, extended
    var id: String { rawValue }

    var label: String {
        switch self {
        case .declared: "Déclarés"
        case .extended: "Avec primaires et pressentis"
        }
    }

    func includes(_ status: CandidacyStatus) -> Bool {
        switch self {
        case .declared: status == .declared || status == .validated
        case .extended: status == .declared || status == .validated || status == .primary || status == .considered
        }
    }
}

struct CandidateAverage: Identifiable, Hashable {
    let candidate: Candidate
    /// Valeur brute, à ne jamais afficher sans passer par `displayed`.
    let raw: Double
    let margin: Double
    let pollCount: Int
    /// Évolution sur la période de tendance ; nil si elle n'est pas calculable.
    let trend: Double?

    var id: String { candidate.id }
    var displayed: Double { AverageEngine.roundHalf(raw) }
    var displayedMargin: Double { AverageEngine.roundHalf(margin) }
    var low: Double { raw - margin }
    var high: Double { raw + margin }
}

struct PollContribution: Identifiable, Hashable {
    let poll: Poll
    let hypothesis: Hypothesis
    let weight: Double
    /// Part de ce sondage dans la moyenne, entre 0 et 1.
    var share: Double
    var id: String { poll.id + "/" + hypothesis.id }
}

struct AverageResult: Hashable {
    let date: Date
    let pollCount: Int
    let averages: [CandidateAverage]
    /// Candidats présents dans moins de sondages que le minimum requis.
    let sparse: [Candidate]
    let contributions: [PollContribution]

    var hasEnoughData: Bool { !averages.isEmpty }
}

struct HistoryPoint: Identifiable, Hashable {
    let date: Date
    let candidate: Candidate
    let value: Double
    var id: String { candidate.id + "@\(date.timeIntervalSince1970)" }
}

struct AverageEngine {
    var settings = AverageSettings()

    static func roundHalf(_ value: Double) -> Double { (value * 2).rounded() / 2 }

    /// Deux candidats dont les fourchettes se recouvrent ne doivent pas être présentés comme nettement séparés.
    static func overlap(_ a: CandidateAverage, _ b: CandidateAverage) -> Bool {
        a.low <= b.high && b.low <= a.high
    }

    func recencyWeight(ageDays: Double) -> Double {
        pow(0.5, max(0, ageDays) / settings.halfLifeDays)
    }

    func sampleWeight(_ sample: Int) -> Double {
        min(settings.maxSampleFactor, (Double(max(0, sample)) / 1000).squareRoot())
    }

    func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }

    /// Hypothèses du 1er tour les plus proches de la liste suivie. Plusieurs en cas d'égalité.
    func bestHypotheses(in poll: Poll, tracked: Set<String>) -> [Hypothesis] {
        var pool = poll.firstRoundHypotheses
        if settings.excludeReducedScenarios {
            // Hypothèse complète : elle contient tous les candidats suivis que le sondage a testés, toutes hypothèses confondues.
            let tested = pool.reduce(into: Set<String>()) { $0.formUnion($1.candidateIDs.intersection(tracked)) }
            let complete = pool.filter { $0.candidateIDs.intersection(tracked) == tested }
            if !complete.isEmpty {
                pool = complete
            } else {
                // Aucune hypothèse complète (variantes de camps) : le sondage reste, avec les hypothèses les plus larges.
                let widest = pool.map { $0.candidateIDs.intersection(tracked).count }.max() ?? 0
                pool = pool.filter { $0.candidateIDs.intersection(tracked).count == widest }
            }
        }
        let scored = pool.map { ($0, jaccard($0.candidateIDs, tracked)) }
        guard let best = scored.map({ $0.1 }).max(), best > 0 else { return [] }
        return scored.filter { abs($0.1 - best) < 1e-9 }.map { $0.0 }
    }

    func average(dataset: Dataset, scope: CandidateScope, at date: Date, includeTrend: Bool = true) -> AverageResult {
        let tracked = dataset.candidates.filter {
            scope.includes($0.status) && !settings.excludedCandidateIDs.contains($0.id)
        }
        let trackedIDs = Set(tracked.map(\.id))
        let day = 86_400.0

        let inWindow = dataset.polls.filter {
            let age = date.timeIntervalSince($0.fieldEnd) / day
            return age >= 0 && age <= settings.windowDays && $0.effectiveSample > 0
        }

        // Un institut très actif ne doit pas dominer : chaque sondage plus ancien du même institut compte moitié moins.
        var instituteRank: [String: Int] = [:]
        for institute in Set(inWindow.map(\.institute)) {
            let ordered = inWindow.filter { $0.institute == institute }
                .sorted { ($0.fieldEnd, $0.id) > ($1.fieldEnd, $1.id) }
            for (rank, poll) in ordered.enumerated() { instituteRank[poll.id] = rank }
        }

        var contributions: [PollContribution] = []
        for poll in inWindow {
            let hypotheses = bestHypotheses(in: poll, tracked: trackedIDs)
            guard !hypotheses.isEmpty else { continue }
            let age = date.timeIntervalSince(poll.fieldEnd) / day
            let rank = Double(instituteRank[poll.id] ?? 0)
            let pollWeight = recencyWeight(ageDays: age)
                * sampleWeight(poll.effectiveSample)
                * pow(settings.instituteDecay, rank)
            // Égalité : le poids est partagé, un sondage ne compte jamais plusieurs fois.
            let shared = pollWeight / Double(hypotheses.count)
            for hypothesis in hypotheses {
                contributions.append(PollContribution(poll: poll, hypothesis: hypothesis, weight: shared, share: 0))
            }
        }

        let total = contributions.map(\.weight).reduce(0, +)
        if total > 0 {
            contributions = contributions.map { item in
                var copy = item
                copy.share = item.weight / total
                return copy
            }.sorted { $0.weight > $1.weight }
        }

        let pollCount = Set(contributions.map(\.poll.id)).count
        guard pollCount >= settings.minimumPolls else {
            return AverageResult(date: date, pollCount: pollCount, averages: [], sparse: [], contributions: contributions)
        }

        var averages: [CandidateAverage] = []
        var sparse: [Candidate] = []
        let previous = includeTrend
            ? average(dataset: dataset, scope: scope, at: date.addingTimeInterval(-settings.trendDays * day), includeTrend: false)
            : nil

        for candidate in tracked {
            let rows = contributions.compactMap { item -> (weight: Double, percent: Double, sample: Double, poll: String)? in
                guard let score = item.hypothesis.scores.first(where: { $0.candidateID == candidate.id }) else { return nil }
                return (item.weight, score.percent, Double(item.poll.effectiveSample), item.poll.id)
            }
            guard Set(rows.map { $0.poll }).count >= settings.minimumPolls else {
                sparse.append(candidate)
                continue
            }
            let sumWeights = rows.map { $0.weight }.reduce(0, +)
            let value = rows.map { $0.weight * $0.percent }.reduce(0, +) / sumWeights
            let variance = rows.map { row -> Double in
                let p = row.percent / 100
                return row.weight * row.weight * p * (1 - p) / row.sample
            }.reduce(0, +)
            let margin = max(settings.minimumMargin, variance.squareRoot() / sumWeights * 1.96 * 100)
            let earlier = previous?.averages.first { $0.candidate.id == candidate.id }?.raw
            averages.append(CandidateAverage(candidate: candidate, raw: value, margin: margin,
                                             pollCount: rows.count, trend: earlier.map { value - $0 }))
        }

        return AverageResult(date: date, pollCount: pollCount,
                             averages: averages.sorted { $0.raw > $1.raw },
                             sparse: sparse.sorted { $0.name < $1.name },
                             contributions: contributions)
    }

    /// Moyenne recalculée chaque semaine, en n'utilisant que les sondages connus à cette date.
    func history(dataset: Dataset, scope: CandidateScope, until date: Date, days: Int) -> [HistoryPoint] {
        var points: [HistoryPoint] = []
        for offset in stride(from: days, through: 0, by: -7) {
            let moment = date.addingTimeInterval(-Double(offset) * 86_400)
            for item in average(dataset: dataset, scope: scope, at: moment, includeTrend: false).averages {
                points.append(HistoryPoint(date: moment, candidate: item.candidate, value: item.raw))
            }
        }
        return points
    }
}
