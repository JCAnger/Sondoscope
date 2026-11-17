import SwiftUI

struct Monogram: View {
    let candidate: Candidate
    var size: CGFloat = 38

    var body: some View {
        Text(candidate.initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Palette.color(for: candidate.id), in: Circle())
            .accessibilityHidden(true)
    }
}

struct DisclaimerLine: View {
    var body: some View {
        Label("Moyenne de sondages, pas une prédiction.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

struct InfoBubble: View {
    let title: String
    let text: String
    @State private var isShown = false

    var body: some View {
        Button { isShown = true } label: {
            Image(systemName: "questionmark.circle")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.accent)
        .accessibilityLabel("Explication : \(title)")
        .popover(isPresented: $isShown) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: 320)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// Date des données et état du dernier téléchargement, en tête de Tendance et de la liste des sondages.
struct DataStatusLine: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let generated = model.activeDataset.generatedAt {
            Text("Données mises à jour le \(Formatting.day(generated))")
                .font(.footnote).foregroundStyle(.secondary)
        }
        if model.lastRefreshFailed {
            Label("Hors ligne : dernières données disponibles affichées", systemImage: "wifi.slash")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// Bouton de barre d'outils : seul moyen d'actualiser sur Mac, où le geste « tirer pour actualiser » n'existe pas.
struct RefreshToolbarItem: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        ToolbarItem {
            if model.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                Button("Actualiser", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    .disabled(model.isSilent)
            }
        }
    }
}

struct DemoBanner: View {
    var body: some View {
        #if DEBUG
        DemoBannerContent()
        #else
        EmptyView()
        #endif
    }
}

#if DEBUG
private struct DemoBannerContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.demoMode {
            Label("Données fictives de démonstration", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(.yellow.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
#endif
