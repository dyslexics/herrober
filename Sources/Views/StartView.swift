import SwiftUI

/// Start: Einband, Weiterlesen, Kapitel, Wege zu Tafeln, Menus, Fibel, Inhaltsverzeichnis.
struct StartView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var nav: Navigator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                einband
                weiterlesen
                kapitelListe
                weitere
            }
            .frame(maxWidth: Theme.leseBreite)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .navigationTitle(T("app.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    private var einband: some View {
        HStack(alignment: .top, spacing: 18) {
            if let img = repo.bild(repo.buch.einband) {
                Image(uiImage: img).resizable().scaledToFit().frame(width: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 6)).shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .accessibilityLabel(T("about.cover"))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(Fraktur.titel(repo.buch.titel)).font(Schrift.fraktur(30)).foregroundStyle(Theme.tinte).accessibilityLabel(repo.buch.titel)
                Text(repo.buch.autoren).font(Schrift.meta).foregroundStyle(Theme.leise)
                Text(repo.buch.ortJahr).font(Schrift.meta).foregroundStyle(Theme.leise)
                Text(T("start.read.count", progress.seitenGelesen, repo.seitenGesamt)).font(Schrift.klein).foregroundStyle(Theme.akzent).padding(.top, 4)
            }
        }
        .padding(.top, 6)
    }

    private var weiterlesen: some View {
        Group {
            if let (k, seite) = progress.weiterlesen(repo) {
                Button { nav.open(.kapitel(k.slug, seite)) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "book.pages").font(.system(size: 26)).foregroundStyle(Theme.aufAkzent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(progress.hatBegonnen ? T("start.continue") : T("start.begin")).font(Schrift.knopf).foregroundStyle(Theme.aufAkzent)
                            Text(k.name + (seite.map { " · " + T("start.page", $0) } ?? "")).font(Schrift.klein).foregroundStyle(Theme.aufAkzent.opacity(0.85)).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.aufAkzent)
                    }
                    .padding(16)
                    .background(Theme.akzent, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var kapitelListe: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("start.chapters")).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
            VStack(spacing: 0) {
                ForEach(repo.kapitel) { k in
                    Button { nav.open(.kapitel(k.slug, nil)) } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(progress.istGelesen(k) ? Theme.erfolg : Theme.weich).frame(width: 34, height: 34)
                                if progress.istGelesen(k) {
                                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.aufAkzent)
                                } else {
                                    Text(k.nummer.split(separator: ".").first.map(String.init) ?? "·").font(Schrift.bold(14)).foregroundStyle(Theme.tinte)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k.titel).font(Schrift.zeile).foregroundStyle(Theme.tinte).multilineTextAlignment(.leading)
                                Text("S. \(k.ersteSeite)–\(k.letzteSeite) · \(progress.gelesen(in: k))/\(k.seiten.count)").font(Schrift.klein).foregroundStyle(Theme.leise)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.leise)
                        }
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if k.slug != repo.kapitel.last?.slug { Divider().overlay(Theme.linie) }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.linie, lineWidth: 1))
        }
    }

    private var weitere: some View {
        VStack(spacing: 10) {
            StartKachel(titel: T("start.tafeln"), unter: T("tafeln.sub"), symbol: "fork.knife") { nav.tab = 1 }
            StartKachel(titel: T("start.menus"), unter: T("menus.sub"), symbol: "list.bullet.rectangle") { nav.tab = 1; nav.open(.menus) }
            StartKachel(titel: T("start.fibel"), unter: T("start.fibel.sub"), symbol: "textformat.abc") { nav.tab = 2 }
            StartKachel(titel: T("start.toc"), unter: T("start.toc.sub"), symbol: "list.number") { nav.open(.toc) }
            StartKachel(titel: T("start.about"), unter: repo.buch.ortJahr, symbol: "info.circle") { nav.open(.ueber) }
        }
    }
}

struct StartKachel: View {
    let titel: String
    let unter: String
    let symbol: String
    let aktion: () -> Void
    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(Theme.akzent).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(Schrift.zeile).foregroundStyle(Theme.tinte)
                    Text(unter).font(Schrift.klein).foregroundStyle(Theme.leise).lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.leise)
            }
            .padding(14)
            .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.linie, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Original-Inhaltsverzeichnis mit Seitenzahlen; Tipp springt ins Kapitel auf die Seite.
struct InhaltsverzeichnisView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    @EnvironmentObject private var settings: Settings

    var body: some View {
        List(Array(repo.bibliothek.inhaltsverzeichnis.enumerated()), id: \.offset) { _, e in
            Button {
                if let k = repo.kapitel.first(where: { k in k.seiten.contains { $0.nr == e.seite } }) { nav.open(.kapitel(k.slug, e.seite)) }
            } label: {
                HStack {
                    Text(settings.altSchrift ? Fraktur.titel(e.titel) : e.titel).font(Schrift.lese(17, alt: settings.altSchrift)).foregroundStyle(Theme.tinte)
                    Spacer()
                    Text(T("toc.page", e.seite)).font(Schrift.meta).foregroundStyle(Theme.leise).monospacedDigit()
                }
            }
            .listRowBackground(Theme.flaeche)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle(T("toc.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
