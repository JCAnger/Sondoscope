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
    /// Par défaut, les hypothèses de retrait ou de candidature unique sont écartées de la moyenne.
    var excludeReducedScenarios = true
    var now = Date()
    #if DEBUG
    var demoMode = false
    #endif

    private let store = DataStore()
    private var engine: AverageEngine {
        AverageEngine(settings: AverageSettings(excludeReducedScenarios: excludeReducedScenarios,
                                                excludedCandidateIDs: excludedCandidateIDs))
    }

    /// Candidats que l'utilisateur suppose retirés. Simulation personnelle, non conservée entre deux lancements.
    var excludedCandidateIDs: Set<String> = []

    func isExcluded(_ id: String) -> Bool { excludedCandidateIDs.contains(id) }

    func setExcluded(_ id: String, _ excluded: Bool) {
        if excluded { excludedCandidateIDs.insert(id) } else { excludedCandidateIDs.remove(id) }
    }

    var activeDataset: Dataset {
        #if DEBUG
        if demoMode { return SampleData.dataset(now: now) }
        #endif
        return dataset
    }

    var isSilent: Bool {
        ElectoralSilence.isActive(at: now, remote: dataset.silencePeriods)
    }

    /// Moyenne mémorisée : elle est lue à chaque évaluation des vues (fiche, liste, widget de tendance).
    var result: AverageResult {
        let key = currentKey
        if let cached = resultCache, cached.key == key { return cached.value }
        let value = engine.average(dataset: activeDataset, scope: scope, at: now)
        resultCache = (key, value)
        return value
    }

    /// Lit toutes les entrées du calcul, même en cas de cache valide, pour que l'observation reste active.
    var currentKey: ResultKey {
        #if DEBUG
        let demo = demoMode
        #else
        let demo = false
        #endif
        return ResultKey(scope: scope, excludeReduced: excludeReducedScenarios, excluded: excludedCandidateIDs,
                         now: now, demo: demo, version: datasetVersion)
    }

    struct ResultKey: Hashable {
        let scope: CandidateScope
        let excludeReduced: Bool
        let excluded: Set<String>
        let now: Date
        let demo: Bool
        let version: Int
    }

    @ObservationIgnored private var resultCache: (key: ResultKey, value: AverageResult)?
    /// Incrémenté à chaque remplacement de `dataset`, pour invalider le cache.
    @ObservationIgnored private var datasetVersion = 0

    /// L'historique coûte 13 à 53 calculs de moyenne : il est mémorisé par durée, comme la moyenne.
    func history(days: Int) -> [HistoryPoint] {
        let key = currentKey
        if let cached = historyCache[days], cached.key == key { return cached.value }
        let value = engine.history(dataset: activeDataset, scope: scope, until: now, days: days)
        historyCache[days] = (key, value)
        return value
    }

    /// Même historique, calculé hors du thread principal : la page Tendance s'affiche sans l'attendre.
    func loadHistory(days: Int) async -> [HistoryPoint] {
        let key = currentKey
        if let cached = historyCache[days], cached.key == key { return cached.value }
        let engine = engine
        let dataset = activeDataset
        let scope = scope
        let now = now
        let value = await Task.detached(priority: .userInitiated) {
            engine.history(dataset: dataset, scope: scope, until: now, days: days)
        }.value
        // Les entrées ont pu changer pendant le calcul : ne mémoriser que si la clé est toujours la bonne.
        if currentKey == key { historyCache[days] = (key, value) }
        return value
    }

    @ObservationIgnored private var historyCache: [Int: (key: ResultKey, value: [HistoryPoint])] = [:]

    var pollsNewestFirst: [Poll] {
        activeDataset.polls.sorted { ($0.fieldEnd, $0.id) > ($1.fieldEnd, $1.id) }
    }

    var candidatesForDisplay: [Candidate] {
        activeDataset.candidates.filter { scope.includes($0.status) }.sorted { $0.name < $1.name }
    }

    func start() async {
        now = Date()
        // Le décodage des fichiers se fait hors du thread principal : la première image n'attend plus le JSON.
        let store = store
        dataset = await Task.detached(priority: .userInitiated) { store.loadBest() }.value
        datasetVersion += 1
        phase = .ready
        await refresh()
    }

    func refresh() async {
        now = Date()
        guard !isSilent else { return }
        do {
            if let remote = try await store.fetchRemote(), remote != dataset {
                dataset = remote
                datasetVersion += 1
            }
            lastRefreshFailed = false
            lastRefresh = Date()
        } catch {
            lastRefreshFailed = true
        }
    }

    /// Appelé au retour au premier plan : l'app peut rester ouverte des jours en arrière-plan.
    func refreshIfStale() async {
        guard phase == .ready else { return }
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 30 * 60 { return }
        await refresh()
    }

    @ObservationIgnored private var lastRefresh: Date?
}
