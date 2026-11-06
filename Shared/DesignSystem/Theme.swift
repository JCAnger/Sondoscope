import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#else
import AppKit
private typealias PlatformColor = NSColor
#endif

extension Color {
    /// Couleur adaptative clair/sombre, disponible aussi dans le widget.
    init(lightHex: UInt32, darkHex: UInt32) {
        func make(_ hex: UInt32) -> PlatformColor {
            PlatformColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                          green: CGFloat((hex >> 8) & 0xFF) / 255,
                          blue: CGFloat(hex & 0xFF) / 255,
                          alpha: 1)
        }
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            make(traits.userInterfaceStyle == .dark ? darkHex : lightHex)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            make(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkHex : lightHex)
        })
        #endif
    }
}

enum Palette {
    static let sky = Color(lightHex: 0xBFE3F7, darkHex: 0x123247)
    static let mint = Color(lightHex: 0xC4EFE0, darkHex: 0x123F3A)
    static let foam = Color(lightHex: 0xEEF9FA, darkHex: 0x0B1D28)
    static let accent = Color(lightHex: 0x1F7FA8, darkHex: 0x7CCBEA)
    static let ink = Color(lightHex: 0x12344A, darkHex: 0xE5F4F8)

    /// Teintes volontairement sans rapport avec les couleurs des partis.
    private static let series: [Color] = [
        Color(lightHex: 0x2B7FA8, darkHex: 0x7CC4E4),
        Color(lightHex: 0x1E8E76, darkHex: 0x72D6BC),
        Color(lightHex: 0x6A6FC4, darkHex: 0xAFB3EE),
        Color(lightHex: 0x8A7A3C, darkHex: 0xD5C57F),
        Color(lightHex: 0x4F7A52, darkHex: 0xA2CDA5),
        Color(lightHex: 0x5E6B7A, darkHex: 0xB4C0CD),
        Color(lightHex: 0x3A8F9E, darkHex: 0x83D3E0),
        Color(lightHex: 0x7E6A9E, darkHex: 0xC6B4E2),
    ]

    /// Couleur stable d'une exécution à l'autre, contrairement à `hashValue`.
    static func color(for candidateID: String) -> Color {
        let sum = candidateID.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return series[sum % series.count]
    }
}

struct AquaBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.foam, Palette.sky, Palette.mint],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Palette.mint.opacity(0.55))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: drift ? 120 : -90, y: drift ? -210 : -150)
            Circle()
                .fill(Palette.sky.opacity(0.7))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: drift ? -130 : 100, y: drift ? 240 : 170)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) { drift = true }
        }
        .accessibilityHidden(true)
    }
}

struct AquaCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Toute la carte réagit au toucher, pas seulement son texte.
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func aquaCard() -> some View { modifier(AquaCard()) }
}

extension Animation {
    static let gentle = Animation.spring(response: 0.7, dampingFraction: 0.86)
}
