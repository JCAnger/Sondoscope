import SwiftUI

struct SilenceView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass").font(.largeTitle).foregroundStyle(Palette.accent)
            Text("Période de silence électoral").font(.title2.bold()).multilineTextAlignment(.center)
            Text("La loi interdit de publier ou de commenter des sondages la veille et le jour du scrutin, jusqu'à la fermeture des derniers bureaux de vote. L'application reprendra ensuite.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 460)
        }
        .padding(24)
    }
}
