#if DEBUG
import Foundation

/// Données FICTIVES, compilées uniquement en Debug et signalées par un bandeau.
enum SampleData {
    static func dataset(now: Date) -> Dataset {
        let names = ["Candidate Alpha", "Candidat Bravo", "Candidate Charlie", "Candidat Delta"]
        let candidates = names.enumerated().map { index, name in
            Candidate(id: "fictif-\(index)", name: name, party: "Mouvement fictif \(index + 1)",
                      status: .declared, detail: "Personnage fictif.", sourceURL: nil, checkedOn: now)
        }
        let base: [Double] = [31, 24, 18, 12]
        let institutes = ["Institut Fictif A", "Institut Fictif B", "Institut Fictif C"]

        let polls = (0..<14).map { index -> Poll in
            let end = now.addingTimeInterval(-Double(index * 9 + 1) * 86_400)
            let scores = candidates.enumerated().map { position, candidate in
                let wave = sin(Double(index + position)) * 1.4 + Double(index) * (position == 0 ? -0.12 : 0.05)
                return Score(candidateID: candidate.id, name: candidate.name, percent: base[position] + wave)
            }
            return Poll(id: "fictif-\(index)", institute: institutes[index % institutes.count],
                        sponsor: "Commanditaire fictif", fieldStart: end.addingTimeInterval(-2 * 86_400),
                        fieldEnd: end, sampleSize: 1_000 + index * 60, voterSampleSize: 900 + index * 50,
                        population: "Inscrits sur les listes électorales", marginNote: "Exemple fictif",
                        noticeURL: nil, source: "Démonstration",
                        hypotheses: [Hypothesis(id: "h1", label: "Hypothèse fictive", round: 1, scores: scores)])
        }
        return Dataset(schemaVersion: 1, generatedAt: now, sources: [], silencePeriods: nil,
                       candidates: candidates, polls: polls)
    }
}
#endif
