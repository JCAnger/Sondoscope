import SwiftUI

@main
struct SondoscopeApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.start()
                    await model.keepFresh()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refreshIfStale() } }
        }
        .commands {
            // ⌘R dans le menu Présentation, sur Mac et sur iPad avec clavier.
            CommandGroup(after: .toolbar) {
                Button("Actualiser les sondages") { Task { await model.refresh() } }
                    .keyboardShortcut("r")
                    .disabled(model.isRefreshing || model.isSilent)
            }
        }
    }
}
