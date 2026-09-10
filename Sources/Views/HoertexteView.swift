import SwiftUI

/// Ergänzende Hörtexte, sobald Aufnahmen über die dokumentierte Schnittstelle vorliegen.
struct HoertexteView: View {
    @State private var suche = ""
    private let katalog = AufnahmenKatalog.shared
    private var treffer: [AufnahmeEintrag] {
        katalog.eintraege.values.filter {
            $0.supplement && (suche.isEmpty || $0.text.localizedStandardContains(suche))
        }.sorted { $0.text.localizedStandardCompare($1.text) == .orderedAscending }
    }
    var body: some View {
        List(treffer) { eintrag in
            NavigationLink {
                HoertextDetail(eintrag: eintrag)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eintrag.text).lineLimit(3)
                    Text(eintrag.language.hasPrefix("fr") ? "Français" : eintrag.language.hasPrefix("en") ? "English" : "Deutsch")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
        }
        .searchable(text: $suche, placement: .navigationBarDrawer(displayMode: .always), prompt: LT("Hörtext suchen", "Search recordings"))
        .navigationTitle(LT("Weitere Hörtexte", "More recordings"))
        .overlay { if treffer.isEmpty { ContentUnavailableView.search(text: suche) } }
    }
}

private struct HoertextDetail: View {
    let eintrag: AufnahmeEintrag
    @StateObject private var stimme = LernStimme()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        LernSeite(titel: LT("Hörtext", "Recording")) {
            LernText(text: eintrag.text, id: eintrag.id, sprache: eintrag.language)
        }
        .environmentObject(stimme)
        .onDisappear { stimme.stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stimme.stop() } }
    }
}
