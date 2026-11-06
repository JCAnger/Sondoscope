import SwiftUI

struct PollDetailView: View {
    @Environment(AppModel.self) private var model
    let polls: [Poll]
    @State private var index: Int
    @State private var isReady = false

    init(polls: [Poll], startIndex: Int) {
        self.polls = polls
        _index = State(initialValue: startIndex)
    }

    private var poll: Poll { polls[index] }

    var body: some View {
        Group {
            if isReady {
                content
                    .transition(.opacity)
            } else {
                loadingView
            }
        }
        .animation(.gentle, value: isReady)
        .navigationTitle(poll.institute)
        // Laisse la navigation se terminer avant de construire le contenu lourd.
        .task {
            await Task.yield()
            isReady = true
        }
    }

    private var loadingView: some View {
        ProgressView {
            Text("Chargement du sondage…")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                DemoBanner()
                identityCard
                ForEach(poll.hypotheses) { hypothesis in
                    hypothesisCard(hypothesis)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .id(poll.id)
            .transition(.opacity)
        }
        .simultaneousGesture(swipe)
        .toolbar {
            ToolbarItemGroup {
                Button { move(by: -1) } label: { Label("Plus récent", systemImage: "chevron.up") }
                    .disabled(index == 0)
                Button { move(by: 1) } label: { Label("Plus ancien", systemImage: "chevron.down") }
                    .disabled(index == polls.count - 1)
            }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 40).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            move(by: value.translation.width < 0 ? 1 : -1)
        }
    }

    private func move(by delta: Int) {
        let next = index + delta
        guard polls.indices.contains(next) else { return }
        withAnimation(.gentle) { index = next }
    }

    private var weightShare: Double? {
        let shares = model.result.contributions.filter { $0.poll.id == poll.id }.map(\.share)
        return shares.isEmpty ? nil : shares.reduce(0, +)
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            info("Institut", poll.institute)
            info("Commanditaire", poll.sponsor)
            info("Terrain", Formatting.range(poll.fieldStart, poll.fieldEnd))
            info("Échantillon", "\(poll.sampleSize) personnes")
            info("Exprimant une intention", poll.voterSampleSize.map { "\($0) personnes" })
            info("Population", poll.population)
            info("Marge d'erreur", poll.marginNote)
            if let weightShare {
                info("Poids dans la moyenne", Formatting.percent((weightShare * 1000).rounded() / 10))
            } else {
                info("Poids dans la moyenne", "Non pris en compte actuellement")
            }
            if let url = poll.noticeURL {
                Link(destination: url) {
                    Label("Consulter la notice officielle", systemImage: "doc.text")
                }
            }
        }
        .aquaCard()
    }

    @ViewBuilder
    private func info(_ title: String, _ value: String?) -> some View {
        if let value {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
        }
    }

    private func hypothesisCard(_ hypothesis: Hypothesis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hypothesis.label ?? "Hypothèse").font(.headline)
            Text(hypothesis.round == 1 ? "1er tour" : "2d tour").font(.caption).foregroundStyle(.secondary)
            ForEach(hypothesis.scores.sorted { $0.percent > $1.percent }) { score in
                HStack {
                    Text(score.name)
                    Spacer()
                    Text(Formatting.percent(score.percent)).monospacedDigit()
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
        .aquaCard()
    }
}
