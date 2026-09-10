import SwiftUI

/// Kapitel „Warum dieses Buch“: redaktioneller Text des DVLD (Content/content.json → warum, Quelle tools/warum.md).
/// Wird wie der Buchtext gesetzt: Antiqua oder Fraktur, Schriftgröße und Zeilenabstand aus den Einstellungen.
struct WarumView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var settings: Settings

    private var bloecke: [Block] { repo.bibliothek.warum ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text(T("about.warum.eyebrow")).font(Schrift.eyebrow).foregroundStyle(Theme.akzent)
                    Spacer()
                    SchriftUmschalter(alt: $settings.altSchrift)
                }
                .padding(.top, 8)
                ForEach(Array(bloecke.enumerated()), id: \.offset) { i, b in
                    BlockView(block: b, seite: -1, index: i, alt: settings.altSchrift)
                }
                Text(T("warum.note"))
                    .font(Schrift.meta)
                    .foregroundStyle(Theme.leise)
                    .padding(.top, 18)
                    .accessibilityIdentifier("warum.note")
            }
            .frame(maxWidth: Theme.leseBreite)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .tint(Theme.akzent)
        .navigationTitle(T("warum.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("warum.view")
    }
}
