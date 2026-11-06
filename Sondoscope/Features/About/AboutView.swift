import SwiftUI

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image("Logo").resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(AppConfig.appName).font(.title2.bold())
                        Text("Les sondages de la présidentielle, en clair").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                NavigationLink {
                    MethodView()
                } label: {
                    Label("Comment c'est calculé ?", systemImage: "function").aquaCard()
                }
                .buttonStyle(.plain)

                section("Indépendance", "Application indépendante, sans lien avec un parti, un candidat ou un institut. Elle ne recommande aucun vote.")
                section("Confidentialité", "Pas de compte, pas de publicité, pas de suivi. Aucune donnée personnelle n'est collectée.")
                section("Limites", "Un sondage mesure un rapport de force à une date donnée. Ce n'est ni un pronostic ni un résultat.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sources et licences").font(.headline)
                    if model.dataset.sources.isEmpty {
                        Text("Aucune source chargée.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(model.dataset.sources) { source in
                        Link(destination: source.url) {
                            Text("\(source.name), \(source.licence)").font(.subheadline)
                        }
                    }
                    Link("Notices de la Commission des sondages",
                         destination: URL(string: "https://www.commission-des-sondages.fr/notices/")!)
                        .font(.subheadline)
                }
                .aquaCard()

                #if DEBUG
                Toggle("Données fictives (Debug uniquement)", isOn: Bindable(model).demoMode).aquaCard()
                #endif
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("À propos")
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text).font(.subheadline)
        }
        .aquaCard()
    }
}

struct MethodView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                step("Fenêtre", "Seuls les sondages terminés depuis moins de 60 jours comptent.")
                step("Récence", "Le poids d'un sondage est divisé par deux tous les 14 jours.")
                step("Échantillon", "Un grand échantillon compte davantage, avec un plafond pour éviter qu'il écrase les autres.")
                step("Diversité", "Pour chaque institut, chaque sondage plus ancien compte moitié moins.")
                step("Hypothèse", "Dans chaque sondage, l'hypothèse la plus proche de la liste suivie est retenue. Un sondage ne compte jamais deux fois.")
                step("Fourchette", "Indication à 95 %, jamais inférieure à ±1 point. Elle reste approximative pour des sondages par quotas.")
                step("Seuil", "En dessous de 3 sondages, aucun score n'est affiché.")

                let contributions = model.result.contributions
                if !contributions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Poids actuels").font(.headline)
                        ForEach(contributions) { item in
                            HStack {
                                Text(item.poll.institute)
                                Text(Formatting.day(item.poll.fieldEnd)).foregroundStyle(.secondary)
                                Spacer()
                                Text(Formatting.percent((item.share * 1000).rounded() / 10)).monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                    }
                    .aquaCard()
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Méthode")
    }

    private func step(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).font(.subheadline)
        }
        .aquaCard()
    }
}
