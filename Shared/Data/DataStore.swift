import Foundation

/// Lit l'instantané embarqué, le cache local et le fichier distant.
struct DataStore {
    enum StoreError: Error { case badStatus }

    private var cacheURL: URL? {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return folder.appendingPathComponent("polls-cache.json")
    }

    func decode(_ data: Data) throws -> Dataset {
        try JSONDecoder.sondoscope.decode(Dataset.self, from: data)
    }

    func loadCached() -> Dataset? {
        guard let cacheURL, let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? decode(data)
    }

    func loadBundled() -> Dataset {
        guard let url = Bundle.main.url(forResource: "polls", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dataset = try? decode(data) else { return .empty }
        return dataset
    }

    func loadBest() -> Dataset {
        let bundled = loadBundled()
        guard let cached = loadCached() else { return bundled }
        return (cached.generatedAt ?? .distantPast) >= (bundled.generatedAt ?? .distantPast) ? cached : bundled
    }

    /// Renvoie nil si aucune URL distante n'est configurée.
    func fetchRemote() async throws -> Dataset? {
        guard let url = AppConfig.remoteDataURL else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadRevalidatingCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw StoreError.badStatus }
        let dataset = try decode(data)
        if let cacheURL {
            try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        }
        return dataset
    }
}
