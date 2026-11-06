import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case trend, polls, candidates, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .trend: "Tendance"
        case .polls: "Sondages"
        case .candidates: "Candidats"
        case .about: "À propos"
        }
    }

    var symbol: String {
        switch self {
        case .trend: "chart.bar.xaxis"
        case .polls: "list.bullet.rectangle"
        case .candidates: "person.2"
        case .about: "info.circle"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("onboardingDone") private var onboardingDone = false

    var body: some View {
        ZStack {
            AquaBackground()
            if model.isSilent {
                SilenceView()
            } else if !onboardingDone {
                OnboardingView { withAnimation(.gentle) { onboardingDone = true } }
                    .transition(.opacity)
            } else {
                MainNavigation()
                    .transition(.opacity)
            }
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
    }
}

private struct MainNavigation: View {
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var selection: AppSection? = .trend

    var body: some View {
        #if os(macOS)
        split
        #else
        if sizeClass == .regular { split } else { tabs }
        #endif
    }

    private var tabs: some View {
        TabView {
            ForEach(AppSection.allCases) { section in
                NavigationStack { content(for: section) }
                    .tabItem { Label(section.title, systemImage: section.symbol) }
            }
        }
    }

    private var split: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
            .navigationTitle(AppConfig.appName)
        } detail: {
            NavigationStack { content(for: selection ?? .trend) }
        }
    }

    @ViewBuilder
    private func content(for section: AppSection) -> some View {
        switch section {
        case .trend: TrendView()
        case .polls: PollsListView()
        case .candidates: CandidatesView()
        case .about: AboutView()
        }
    }
}
