import SwiftUI

struct EinstellungenView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var nav: Navigator
    @State private var resetFrage = false

    var body: some View {
        Form {
            Section(T("settings.reading")) {
                Picker(T("settings.schrift"), selection: $settings.altSchrift) {
                    Text(T("schrift.alt")).tag(true)
                    Text(T("schrift.neu")).tag(false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(T("settings.textsize")); Spacer(); Text(T("settings.pt", Int(settings.fontSize))).foregroundStyle(Theme.leise) }
                    Slider(value: $settings.fontSize, in: Settings.groessen, step: 1).tint(Theme.akzent)
                }
                Picker(T("settings.spacing"), selection: $settings.lineFactor) {
                    ForEach(Settings.zeilenFaktoren, id: \.self) { f in Text(String(format: "%.1f", locale: Locale(identifier: L10n.lang), f)).tag(f) }
                }
                .pickerStyle(.segmented)
                Text(settings.altSchrift ? Fraktur.titel(T("settings.preview")) : T("settings.preview"))
                    .font(Schrift.lese(CGFloat(settings.fontSize), alt: settings.altSchrift))
                    .lineSpacing(settings.lineSpacing)
                    .foregroundStyle(Theme.tinte)
                    .accessibilityLabel(T("settings.preview"))
            }
            Section(T("settings.language")) {
                Picker(T("settings.language"), selection: $settings.lang) {
                    Text(T("settings.lang.system")).tag(AppLang.system)
                    Text("Deutsch").tag(AppLang.de)
                    Text("English").tag(AppLang.en)
                }
                .pickerStyle(.segmented)
            }
            Section(T("settings.appearance")) {
                Picker(T("settings.appearance"), selection: $settings.darstellung) {
                    Text(T("settings.appearance.system")).tag(Darstellung.system)
                    Text(T("settings.appearance.light")).tag(Darstellung.hell)
                    Text(T("settings.appearance.dark")).tag(Darstellung.dunkel)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Button { nav.open(.ueber) } label: { Label(T("settings.about"), systemImage: "book.closed") }
                Button(role: .destructive) { resetFrage = true } label: { Label(T("settings.reset"), systemImage: "arrow.counterclockwise") }
            } footer: {
                Text(T("settings.idea"))
                    .font(Schrift.meta)
                    .foregroundStyle(Theme.leise)
                    .accessibilityIdentifier("settings.idea")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Theme.akzent)
        .navigationTitle(T("settings.title"))
        .confirmationDialog(T("settings.reset.confirm"), isPresented: $resetFrage, titleVisibility: .visible) {
            Button(T("settings.reset.do"), role: .destructive) { progress.reset() }
            Button(T("common.cancel"), role: .cancel) {}
        }
    }
}

/// Über das Buch und die App: Einband, Titelblatt, Vorsatz-Texte, Über-Text, Lizenzen.
struct UeberView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var settings: Settings

    private var versionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = info["CFBundleShortVersionString"] as? String ?? ""
        let b = info["CFBundleVersion"] as? String ?? ""
        return "\(T("about.version")) \(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ForEach([repo.buch.einband, repo.buch.titelblatt], id: \.self) { name in
                        if let img = repo.bild(name) {
                            Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 8)).shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                ForEach(Array(repo.bibliothek.ueber.enumerated()), id: \.offset) { i, b in
                    BlockView(block: b, seite: -1, index: i, alt: false)
                }
                ForEach(Array(repo.bibliothek.vorsatz.enumerated()), id: \.offset) { _, s in
                    if !s.bloecke.isEmpty && s.titel != "Einband" && s.titel != "Inhaltsverzeichnis" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(s.titel).font(Schrift.eyebrow).foregroundStyle(Theme.akzent).padding(.top, 8)
                            ForEach(Array(s.bloecke.enumerated()), id: \.offset) { i, b in
                                BlockView(block: b, seite: -1, index: i, alt: settings.altSchrift)
                            }
                        }
                    }
                }
                Text(T("about.local")).font(Schrift.meta).foregroundStyle(Theme.leise).padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    Link(destination: Links.privacy) { Label(T("about.privacy"), systemImage: "hand.raised") }
                    Link(destination: Links.kontakt) { Label(T("about.contact"), systemImage: "envelope") }
                    Link(destination: Links.quellcode) { Label(T("about.source"), systemImage: "chevron.left.forwardslash.chevron.right") }
                    Text(versionText).font(Schrift.klein).foregroundStyle(Theme.leise)
                }
                .font(Schrift.text)
            }
            .frame(maxWidth: Theme.leseBreite)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .tint(Theme.akzent)
        .navigationTitle(T("about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
