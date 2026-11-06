import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, title: String, text: String)] = [
        ("chart.bar.xaxis", "L'essentiel en un coup d'œil", "Une moyenne claire de tous les sondages récents, avec les plus récents au premier plan."),
        ("list.bullet.rectangle", "Chaque sondage, un par un", "Parcourez-les du plus récent au plus ancien, avec leur méthode et leur notice officielle."),
        ("scalemass", "Neutre et transparent", "Un sondage n'est pas une prédiction. L'application ne recommande aucun vote."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("Logo").resizable().frame(width: 96, height: 96).accessibilityHidden(true)
            VStack(spacing: 12) {
                Image(systemName: pages[page].symbol).font(.largeTitle).foregroundStyle(Palette.accent)
                Text(pages[page].title).font(.title.bold()).multilineTextAlignment(.center)
                Text(pages[page].text).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            .id(page)
            .transition(.opacity)
            .frame(maxWidth: 420)
            Spacer()
            Button(page == pages.count - 1 ? "Commencer" : "Suivant") {
                if page == pages.count - 1 {
                    onFinish()
                } else {
                    withAnimation(.gentle) { page += 1 }
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            Button("Passer", action: onFinish).buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
