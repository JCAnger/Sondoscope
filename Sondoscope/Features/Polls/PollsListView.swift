import SwiftUI

struct PollsListView: View {
    @Environment(AppModel.self) private var model
    @State private var institute = "Tous"
    @State private var periodDays = 0

    private var filtered: [Poll] {
        model.pollsNewestFirst.filter { poll in
            let matchesInstitute = institute == "Tous" || poll.institute == institute
            let matchesPeriod = periodDays == 0
                || model.now.timeIntervalSince(poll.fieldEnd) <= Double(periodDays) * 86_400
            return matchesInstitute && matchesPeriod
        }
    }

    private var institutes: [String] {
        ["Tous"] + Set(model.pollsNewestFirst.map(\.institute)).sorted()
    }

    var body: some View {
        let polls = filtered

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                DemoBanner()
                HStack {
                    Picker("Institut", selection: $institute) {
                        ForEach(institutes, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Période", selection: $periodDays) {
                        Text("Toute la période").tag(0)
                        Text("30 jours").tag(30)
                        Text("90 jours").tag(90)
                    }
                }
                .pickerStyle(.menu)

                if polls.isEmpty {
                    ContentUnavailableView("Aucun sondage", systemImage: "tray",
                                           description: Text("Aucun sondage ne correspond à ces critères."))
                }
                ForEach(Array(polls.enumerated()), id: \.element.id) { index, poll in
                    NavigationLink {
                        PollDetailView(polls: polls, startIndex: index)
                    } label: {
                        PollRow(poll: poll).aquaCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await model.refresh() }
        .navigationTitle("Sondages")
    }
}

private struct PollRow: View {
    let poll: Poll

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(poll.institute).font(.headline)
            if let sponsor = poll.sponsor {
                Text("pour \(sponsor)").font(.subheadline).foregroundStyle(.secondary)
            }
            Text(Formatting.range(poll.fieldStart, poll.fieldEnd)).font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
