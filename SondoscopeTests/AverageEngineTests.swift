import Foundation
import Testing

private let day = 86_400.0
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func candidate(_ id: String, _ status: CandidacyStatus = .declared) -> Candidate {
    Candidate(id: id, name: id.uppercased(), party: nil, status: status, detail: nil, sourceURL: nil, checkedOn: nil)
}

private func hypothesis(_ id: String, _ scores: [String: Double]) -> Hypothesis {
    Hypothesis(id: id, label: nil, round: 1,
               scores: scores.map { Score(candidateID: $0.key, name: $0.key, percent: $0.value) })
}

private func poll(_ id: String, institute: String? = nil, ageDays: Double, sample: Int = 1000,
                  hypotheses: [Hypothesis]) -> Poll {
    let end = now.addingTimeInterval(-ageDays * day)
    return Poll(id: id, institute: institute ?? "I-\(id)", sponsor: nil, fieldStart: end, fieldEnd: end,
                sampleSize: sample, voterSampleSize: nil, population: nil, marginNote: nil,
                noticeURL: nil, source: nil, hypotheses: hypotheses)
}

private func dataset(_ candidates: [Candidate], _ polls: [Poll]) -> Dataset {
    Dataset(schemaVersion: 1, generatedAt: nil, sources: [], silencePeriods: nil, candidates: candidates, polls: polls)
}

@Suite struct AverageEngineTests {
    let engine = AverageEngine()

    @Test func recencyHalvesEveryFourteenDays() {
        #expect(abs(engine.recencyWeight(ageDays: 14) - 0.5) < 1e-9)
        #expect(abs(engine.recencyWeight(ageDays: 28) - 0.25) < 1e-9)
    }

    @Test func sampleWeightIsCapped() {
        #expect(abs(engine.sampleWeight(1000) - 1) < 1e-9)
        #expect(engine.sampleWeight(100_000) == 1.5)
    }

    @Test func roundsToHalfPoint() {
        #expect(AverageEngine.roundHalf(23.3) == 23.5)
        #expect(AverageEngine.roundHalf(23.2) == 23)
    }

    @Test func recentPollWeighsMore() {
        let polls = [
            poll("a", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30])]),
            poll("b", ageDays: 14, hypotheses: [hypothesis("h", ["x": 20])]),
            poll("c", ageDays: 28, hypotheses: [hypothesis("h", ["x": 10])]),
        ]
        let result = engine.average(dataset: dataset([candidate("x")], polls), scope: .declared, at: now)
        // (1×30 + 0,5×20 + 0,25×10) / 1,75 = 24,2857…
        #expect(abs(result.averages[0].raw - 42.5 / 1.75) < 1e-9)
    }

    @Test func secondPollOfSameInstituteIsHalved() {
        let polls = [
            poll("a", institute: "I", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30])]),
            poll("b", institute: "I", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30])]),
            poll("c", institute: "J", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30])]),
        ]
        let result = engine.average(dataset: dataset([candidate("x")], polls), scope: .declared, at: now)
        #expect(abs(result.contributions.map(\.weight).reduce(0, +) - 2.5) < 1e-9)
    }

    @Test func tiedHypothesesSplitWeight() {
        let tied = poll("a", ageDays: 0, hypotheses: [
            hypothesis("h1", ["x": 30, "y": 20]),
            hypothesis("h2", ["x": 34, "y": 16]),
        ])
        let others = [
            poll("b", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30, "y": 20])]),
            poll("c", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30, "y": 20])]),
        ]
        let result = engine.average(dataset: dataset([candidate("x"), candidate("y")], [tied] + others),
                                    scope: .declared, at: now)
        #expect(result.pollCount == 3)
        #expect(abs(result.contributions.map(\.weight).reduce(0, +) - 3) < 1e-9)
        #expect(abs(result.averages[0].raw - (15 + 17 + 30 + 30) / 3) < 1e-9)
    }

    @Test func closestHypothesisIsChosen() {
        let target = poll("a", ageDays: 0, hypotheses: [
            hypothesis("far", ["x": 30, "z": 20]),
            hypothesis("near", ["x": 30, "y": 20]),
        ])
        let picked = engine.bestHypotheses(in: target, tracked: ["x", "y"])
        #expect(picked.map(\.id) == ["near"])
    }

    @Test func candidateAbsentFromPollsIsNotAveragedWithZero() {
        let polls = [
            poll("a", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30, "y": 10])]),
            poll("b", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30, "y": 10])]),
            poll("c", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30, "y": 10])]),
            poll("d", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30])]),
        ]
        let result = engine.average(dataset: dataset([candidate("x"), candidate("y")], polls), scope: .declared, at: now)
        #expect(abs(result.averages.first { $0.candidate.id == "y" }!.raw - 10) < 1e-9)
    }

    @Test func fewerThanThreePollsGivesNoScore() {
        let polls = [
            poll("a", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30])]),
            poll("b", ageDays: 0, hypotheses: [hypothesis("h", ["x": 30])]),
        ]
        let result = engine.average(dataset: dataset([candidate("x")], polls), scope: .declared, at: now)
        #expect(!result.hasEnoughData)
    }

    @Test func emptyDatasetIsSafe() {
        #expect(!engine.average(dataset: .empty, scope: .declared, at: now).hasEnoughData)
    }

    @Test func oldAndFuturePollsAreIgnored() {
        let polls = [
            poll("old", ageDays: 61, hypotheses: [hypothesis("h", ["x": 30])]),
            poll("future", ageDays: -1, hypotheses: [hypothesis("h", ["x": 30])]),
        ]
        #expect(engine.average(dataset: dataset([candidate("x")], polls), scope: .declared, at: now).pollCount == 0)
    }

    @Test func scopeFiltersConsideredCandidates() {
        let candidates = [candidate("x"), candidate("y", .considered)]
        let polls = ["a", "b", "c"].map { poll($0, ageDays: 0, hypotheses: [hypothesis("h", ["x": 30, "y": 20])]) }
        let data = dataset(candidates, polls)
        #expect(engine.average(dataset: data, scope: .declared, at: now).averages.map(\.candidate.id) == ["x"])
        #expect(engine.average(dataset: data, scope: .extended, at: now).averages.count == 2)
    }

    @Test func marginHasOnePointFloor() {
        let polls = ["a", "b", "c", "d", "e", "f"].map {
            poll($0, ageDays: 0, sample: 100_000, hypotheses: [hypothesis("h", ["x": 30])])
        }
        let result = engine.average(dataset: dataset([candidate("x")], polls), scope: .declared, at: now)
        #expect(result.averages[0].margin == 1)
    }

    @Test func overlapDetection() {
        let polls = ["a", "b", "c"].map { poll($0, ageDays: 0, hypotheses: [hypothesis("h", ["x": 25, "y": 24, "z": 10])]) }
        let list = engine.average(dataset: dataset([candidate("x"), candidate("y"), candidate("z")], polls),
                                  scope: .declared, at: now).averages
        #expect(AverageEngine.overlap(list[0], list[1]))
        #expect(!AverageEngine.overlap(list[0], list[2]))
    }
}

@Suite struct ElectoralSilenceTests {
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func firstRoundBoundaries() {
        #expect(!ElectoralSilence.isActive(at: date("2027-04-16T23:59:59+02:00")))
        #expect(ElectoralSilence.isActive(at: date("2027-04-17T00:00:00+02:00")))
        #expect(ElectoralSilence.isActive(at: date("2027-04-18T19:59:59+02:00")))
        #expect(!ElectoralSilence.isActive(at: date("2027-04-18T20:00:00+02:00")))
    }

    @Test func secondRoundBoundaries() {
        #expect(!ElectoralSilence.isActive(at: date("2027-04-30T23:59:59+02:00")))
        #expect(ElectoralSilence.isActive(at: date("2027-05-01T00:00:00+02:00")))
        #expect(ElectoralSilence.isActive(at: date("2027-05-02T19:59:59+02:00")))
        #expect(!ElectoralSilence.isActive(at: date("2027-05-02T20:00:00+02:00")))
    }

    @Test func remotePeriodsAddButNeverRemove() {
        let extra = SilencePeriod(start: date("2027-06-01T00:00:00+02:00"), end: date("2027-06-02T00:00:00+02:00"))
        #expect(ElectoralSilence.isActive(at: date("2027-06-01T12:00:00+02:00"), remote: [extra]))
        #expect(ElectoralSilence.isActive(at: date("2027-04-17T12:00:00+02:00"), remote: []))
    }
}

@Suite struct DecodingTests {
    @Test func decodesPipelineFormat() throws {
        let json = #"""
        {"schemaVersion":1,"generatedAt":"2026-11-06T10:00:00Z","sources":[],"silencePeriods":[],
         "candidates":[{"id":"x","name":"Jane Doe","party":null,"status":"nouveau-statut"}],
         "polls":[{"id":"p","institute":"I","fieldStart":"2026-11-01","fieldEnd":"2026-11-02","sampleSize":1000,
                   "hypotheses":[{"id":"h","round":1,"scores":[{"candidateID":"x","name":"Jane Doe","percent":12.5}]}]}]}
        """#
        let dataset = try JSONDecoder.sondoscope.decode(Dataset.self, from: Data(json.utf8))
        #expect(dataset.polls[0].hypotheses[0].scores[0].percent == 12.5)
        #expect(dataset.candidates[0].status == .unknown)
        #expect(dataset.candidates[0].initials == "JD")
    }
}
