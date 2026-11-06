import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable { case loading, ready, failed }

    private(set) var dataset: Dataset = .empty
    private(set) var phase: Phase = .loading
    private(set) var lastRefreshFailed = false
    var scope: CandidateScope = .declared
    var now = Date()
    #if DEBUG
    var demoMode = false
    #endif

    private let store = DataStore()
    private let engine = AverageEngine()

    var activeDataset: Dataset {
        #if DEBUG
        if demoMode { return SampleData.dataset(now: now) }
        #endif
        return dataset
    }

    var isSilent: Bool {
        ElectoralSilence.isActive(at: now, remote: dataset.silencePeriods)
    }

    var result: AverageResult { engine.average(dataset: activeDataset, scope: scope, at: now) }

    func history(days: Int) -> [HistoryPoint] {
        engine.history(dataset: activeDataset, scope: scope, until: now, days: days)
    }

    var pollsNewestFirst: [Poll] {
        activeDataset.polls.sorted { ($0.fieldEnd, $0.id) > ($1.fieldEnd, $1.id) }
    }

    var candidatesForDisplay: [Candidate] {
        activeDataset.candidates.filter { scope.includes($0.status) }.sorted { $0.name < $1.name }
    }

    func start() async {
        now = Date()
        dataset = store.loadBest()
        phase = .ready
        await refresh()
    }

    func refresh() async {
        now = Date()
        guard !isSilent else { return }
        do {
            if let remote = try await store.fetchRemote() { dataset = remote }
            lastRefreshFailed = false
        } catch {
            lastRefreshFailed = true
        }
    }
}
