import SwiftUI

/// Page de chargement reprenant les bandeaux du store (branding/appstore) : dégradé, halos, courbes, icône et phrase.
/// L'icône démarre à la taille et à la place du logo de l'écran de lancement système, puis grandit doucement.
struct LaunchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private static let startSize: CGFloat = 96
    private static let endSize: CGFloat = 136

    var body: some View {
        ZStack {
            LaunchBackdrop()
            icon
                .overlay(alignment: .top) {
                    tagline
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 340)
                        .offset(y: Self.endSize / 2 + Self.startSize / 2 + 32)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed || reduceMotion ? 0 : 12)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sondoscope. Tous les sondages, une seule moyenne.")
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .gentle.delay(0.1)) { revealed = true }
        }
    }

    private var icon: some View {
        let size = Self.startSize
        return Image("LaunchIcon")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .shadow(color: Palette.ink.opacity(0.22), radius: 14, y: 8)
            // Mise à l'échelle plutôt que changement de cadre : le centre reste celui du logo système.
            .scaleEffect(revealed || reduceMotion ? Self.endSize / size : 1)
    }

    private var tagline: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("Tous les sondages,").foregroundStyle(Palette.ink)
                Text("une seule moyenne.").foregroundStyle(Palette.accent)
            }
            .font(.title.weight(.semibold))
            Text("Institut, dates, échantillon et notice pour chaque sondage.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.accent)
        }
        .multilineTextAlignment(.center)
    }
}

/// Fond des bandeaux : mêmes teintes que generate_appstore.py, avec une variante sombre tirée de `Palette`.
private struct LaunchBackdrop: View {
    private let top = Color(lightHex: 0xD3EEFA, darkHex: 0x0B1D28)
    private let middle = Color(lightHex: 0xA9DDEF, darkHex: 0x123247)
    private let bottom = Color(lightHex: 0x8FD9C4, darkHex: 0x123F3A)
    private let glow = Color(lightHex: 0xFFFFFF, darkHex: 0x1F4A63)
    private let curveGreen = Color(lightHex: 0x1E8E76, darkHex: 0x72D6BC)

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let blur = min(w, h) * 0.18
            ZStack {
                LinearGradient(stops: [.init(color: top, location: 0),
                                       .init(color: middle, location: 0.55),
                                       .init(color: bottom, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                halo(Palette.mint, opacity: 0.8, diameter: h * 0.6, blur: blur).position(x: w * 0.15, y: h * 0.1)
                halo(Palette.sky, opacity: 0.9, diameter: h * 0.65, blur: blur).position(x: w * 0.88, y: h * 0.95)
                halo(glow, opacity: 0.55, diameter: h * 0.4, blur: blur).position(x: w * 0.78, y: h * 0.05)
                // Courbes purement décoratives : elles ne représentent aucune donnée.
                Wave(levels: (0.84, 0.76, 0.90, 0.80, 0.66, 0.74))
                    .stroke(Palette.accent.opacity(0.12), lineWidth: 2)
                Wave(levels: (0.91, 0.86, 0.96, 0.88, 0.80, 0.84))
                    .stroke(curveGreen.opacity(0.10), lineWidth: 2)
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func halo(_ color: Color, opacity: Double, diameter: CGFloat, blur: CGFloat) -> some View {
        Circle().fill(color.opacity(opacity)).frame(width: diameter, height: diameter).blur(radius: blur)
    }
}

/// Même tracé que les chemins SVG des bandeaux, en proportions de la vue.
private struct Wave: Shape {
    /// Hauteurs relatives : départ, 1er point de contrôle, 2e point de contrôle, milieu, point de contrôle réfléchi, arrivée.
    let levels: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let mid = CGPoint(x: w * 0.5, y: h * levels.3)
        let c2 = CGPoint(x: w * 0.3, y: h * levels.2)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * levels.0))
        path.addCurve(to: mid, control1: CGPoint(x: w * 0.18, y: h * levels.1), control2: c2)
        // Équivalent de la commande SVG « S » : premier point de contrôle réfléchi autour du milieu.
        path.addCurve(to: CGPoint(x: w, y: h * levels.5),
                      control1: CGPoint(x: 2 * mid.x - c2.x, y: 2 * mid.y - c2.y),
                      control2: CGPoint(x: w * 0.8, y: h * levels.4))
        return path
    }
}

#Preview {
    LaunchView()
}
