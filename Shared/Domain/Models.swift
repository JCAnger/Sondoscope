import Foundation

/// Fichier `polls.json` produit par le pipeline. L'app ne lit jamais directement les sources externes.
struct Dataset: Codable, Hashable {
    var schemaVersion: Int
    var generatedAt: Date?
    var sources: [DataSource]
    var silencePeriods: [SilencePeriod]?
    var candidates: [Candidate]
    var polls: [Poll]

    static let empty = Dataset(schemaVersion: 1, generatedAt: nil, sources: [], silencePeriods: nil, candidates: [], polls: [])
}

struct DataSource: Codable, Hashable, Identifiable {
    var name: String
    var url: URL
    var licence: String
    var id: String { name }
}

enum CandidacyStatus: String, Codable, CaseIterable, Hashable {
    case declared = "declaree"
    case primary = "primaire"
    case considered = "pressentie"
    case validated = "validee"
    case prevented = "empechee"
    case withdrawn = "renoncement"
    case unknown = "inconnu"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CandidacyStatus(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .declared: "Déclarée"
        case .primary: "En primaire"
        case .considered: "Pressentie"
        case .validated: "Validée"
        case .prevented: "Empêchée"
        case .withdrawn: "Renoncement"
        case .unknown: "Non précisé"
        }
    }
}

struct Candidate: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var party: String?
    var status: CandidacyStatus
    var detail: String?
    var sourceURL: URL?
    var checkedOn: Date?

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

struct Poll: Codable, Hashable, Identifiable {
    var id: String
    var institute: String
    var sponsor: String?
    var fieldStart: Date
    var fieldEnd: Date
    var sampleSize: Int
    /// Échantillon ayant exprimé une intention de vote, si publié.
    var voterSampleSize: Int?
    var population: String?
    var marginNote: String?
    var noticeURL: URL?
    var source: String?
    var hypotheses: [Hypothesis]

    var effectiveSample: Int { voterSampleSize ?? sampleSize }
    var firstRoundHypotheses: [Hypothesis] { hypotheses.filter { $0.round == 1 } }
}

struct Hypothesis: Codable, Hashable, Identifiable {
    var id: String
    var label: String?
    var round: Int
    var scores: [Score]

    var candidateIDs: Set<String> { Set(scores.map(\.candidateID)) }
}

struct Score: Codable, Hashable, Identifiable {
    var candidateID: String
    var name: String
    var percent: Double
    var id: String { candidateID }
}

extension JSONDecoder {
    static var sondoscope: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = DateParsing.parse(text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Date invalide : \(text)"))
        }
        return decoder
    }
}

enum DateParsing {
    static let paris = TimeZone(identifier: "Europe/Paris")!

    // Créés une fois : instancier un formateur par date ralentissait le décodage de tout le fichier.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = paris
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    private static let isoFormatter = ISO8601DateFormatter()

    static func parse(_ text: String) -> Date? {
        if let day = dayFormatter.date(from: text) { return day }
        return isoFormatter.date(from: text)
    }
}
