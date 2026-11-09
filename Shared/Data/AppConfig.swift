import Foundation

enum AppConfig {
    static let appName = "Sondoscope"

    /// Fichier publié chaque jour par `.github/workflows/update-polls.yml`.
    /// Si la valeur est nil, l'app n'utilise que l'instantané embarqué.
    static let remoteDataURL = URL(string: "https://jcanger.github.io/Sondoscope/polls.json")
}
