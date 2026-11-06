import Foundation

enum AppConfig {
    static let appName = "Sondoscope"

    /// À renseigner après l'activation de GitHub Pages, par exemple
    /// URL(string: "https://mon-compte.github.io/Sondoscope/polls.json").
    /// Tant que la valeur est nil, l'app n'utilise que l'instantané embarqué.
    static let remoteDataURL: URL? = nil
}
