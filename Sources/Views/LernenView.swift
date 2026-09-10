import SwiftUI

struct LernRouteView: View {
    let art: String
    let id: String
    @EnvironmentObject private var repo: ContentRepository
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var stimme = LernStimme()
    var body: some View {
        ziel.environmentObject(stimme)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle(LT("Langsam vorlesen", "Read slowly"), isOn: $stimme.langsam)
                        if stimme.aktiv != nil { Button(LT("Vorlesen stoppen", "Stop reading")) { stimme.stop() } }
                    } label: { Image(systemName: "speaker.wave.2").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel(LT("Vorleseoptionen", "Reading options"))
                }
            }
            .onDisappear { stimme.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { stimme.stop() } }
    }
    @ViewBuilder private var ziel: some View {
        switch art {
        case "hub": LernStartView()
        case "glossar": GlossarView()
        case "begriff": if let b = repo.lernen.begriff(id) { BegriffView(begriff: b) }
        case "fragen": if id.isEmpty { FragenAuswahlView() } else { KapitelFragenView(auswahl: id) }
        case "tour": if let t = repo.lernen.touren.first(where: { $0.id == id }) { TourView(tour: t) }
        case "kontext": KontextView(id: id)
        case "leseuebungen": LeseUebungenView(start: id)
        case "bilder": BildAufgabenListe()
        case "bild": if let a = repo.lernen.bildaufgaben.first(where: { $0.id == id }) { BildAufgabeView(aufgabe: a) }
        case "menuhilfe": if let m = repo.lernen.menufuehrer.first(where: { $0.menu == id }) { MenuFuehrerView(menu: m) }
        default: ContentUnavailableView(LT("Inhalt nicht gefunden", "Content not found"), systemImage: "book.closed")
        }
    }
}

struct LernSeite<Inhalt: View>: View {
    let titel: String
    @ViewBuilder let inhalt: () -> Inhalt
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20, content: inhalt)
                .frame(maxWidth: Theme.leseBreite).frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.seite).padding(.vertical, 20)
        }
        .background(Theme.bg).foregroundStyle(Theme.tinte).tint(Theme.akzent)
        .navigationTitle(titel).navigationBarTitleDisplayMode(.inline)
    }
}

struct LernText: View {
    let text: String
    let id: String
    var alt: String? = nil
    var antiqua: [[Int]] = []
    var map: [Int] = []
    var sprache = "de-AT"
    @EnvironmentObject private var stimme: LernStimme
    @EnvironmentObject private var settings: Settings
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AbsatzText(text: alt ?? text, antiqua: antiqua.compactMap { $0.count == 2 ? $0[0]..<$0[1] : nil },
                       alt: alt != nil, groesse: CGFloat(settings.fontSize), zeilenabstand: settings.lineSpacing,
                       markierung: markierung, zugaenglich: text)
            Button { stimme.lesen(text, id: id, sprache: sprache) } label: {
                Label(stimme.aktiv == id ? LT("Stoppen", "Stop") : LT("Anhören", "Listen"), systemImage: stimme.aktiv == id ? "stop.circle" : "speaker.wave.2")
                    .font(Schrift.meta).frame(minHeight: 44)
            }
            .accessibilityIdentifier("listen.\(id)")
        }
    }
    private var markierung: Range<Int>? {
        guard let r = stimme.markierung(text, id: id) else { return nil }
        if alt != nil, map.indices.contains(r.upperBound) { return map[r.lowerBound]..<map[r.upperBound] }
        return r
    }
}

struct RedaktionHinweis: View {
    var body: some View {
        Text(LT("Heute erklärt · Ergänzungen zum Buch von 1899", "Explained today · Companion to the 1899 book"))
            .font(Schrift.klein).foregroundStyle(Theme.leise)
    }
}

struct QuellenKnopf: View {
    let quelle: LernQuelle
    var mitZitat = false
    var oeffnen: ((Route) -> Void)? = nil
    @EnvironmentObject private var nav: Navigator
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if mitZitat, let z = quelle.zitat {
                DisclosureGroup(LT("Buchstelle einblenden", "Show passage")) {
                    Text(z).font(Schrift.text).textSelection(.enabled).padding(.vertical, 8)
                }.font(Schrift.meta)
            }
            Button { if let oeffnen { oeffnen(quelle.ziel.route) } else { nav.open(quelle.ziel.route) } } label: {
                Label(quelle.titel, systemImage: "book.pages").font(Schrift.zeile)
                    .multilineTextAlignment(.leading).frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("learning.source")
        }
    }
}

struct LernStartView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    @EnvironmentObject private var progress: ProgressStore
    var body: some View {
        LernSeite(titel: LT("Entdecken & lernen", "Discover & learn")) {
            SeitenKopf(titel: LT("Ein Buch zum Mitmachen", "Explore the book"), untertitel: LT("Lesen, hinschauen und verstehen – in deinem Tempo.", "Read, look closely and understand — at your own pace."))
            RedaktionHinweis()
            if L10n.lang == "en" { Text("The book and learning content are in German.").font(Schrift.meta) }
            Text(LT("Entdeckungstouren", "Discovery tours")).font(Schrift.abschnitt)
            ForEach(repo.lernen.touren) { t in
                let n = t.schritte.filter { progress.lern.tourSchritte.contains("\(t.id)/\($0.id)") }.count
                StartKachel(titel: t.titel, unter: "\(t.dauer) · \(n)/\(t.schritte.count)", symbol: n == t.schritte.count ? "checkmark.circle" : "map") { nav.open(.lernen("tour", t.id)) }
                    .accessibilityIdentifier("tour.\(t.id)")
            }
            Text(LT("Selbst wählen", "Choose an activity")).font(Schrift.abschnitt)
            StartKachel(titel: LT("Wörter verstehen", "Understand words"), unter: LT("40 Begriffe · suchen und merken", "40 terms · search and save"), symbol: "character.book.closed") { nav.open(.lernen("glossar", "")) }.accessibilityIdentifier("learning.glossary")
            StartKachel(titel: LT("Zum Kapitel nachdenken", "Chapter questions"), unter: LT("30 Fragen mit Erklärung und Buchstelle", "30 questions with explanations and sources"), symbol: "questionmark.bubble") { nav.open(.lernen("fragen", "")) }.accessibilityIdentifier("learning.questions")
            if !progress.lern.wiederholen.isEmpty {
                StartKachel(titel: LT("Noch einmal ansehen", "Review again"), unter: "\(progress.lern.wiederholen.count) " + LT("Fragen zum Wiederholen", "questions to revisit"), symbol: "arrow.counterclockwise") { nav.open(.lernen("fragen", "wiederholen")) }.accessibilityIdentifier("learning.review")
            }
            StartKachel(titel: LT("Mit Bildern lernen", "Learn with pictures"), unter: LT("Besteck erkennen und einen Platz decken", "Recognise cutlery and set a place"), symbol: "fork.knife") { nav.open(.lernen("bilder", "")) }.accessibilityIdentifier("learning.images")
            StartKachel(titel: LT("Wortgruppen & Sätze", "Phrases & sentences"), unter: LT("12 Übungen zum Lesen der Fraktur", "12 exercises in reading Fraktur"), symbol: "textformat.abc") { nav.open(.lernen("leseuebungen", "gruppe")) }
            if let m = repo.lernen.menufuehrer.first {
                StartKachel(titel: LT("Die Strauss-Karte verstehen", "Explore the Strauss menu"), unter: m.titel, symbol: "list.bullet.rectangle") { nav.open(.lernen("menuhilfe", m.menu)) }.accessibilityIdentifier("learning.menu")
            }
            StartKachel(titel: LT("Einblicke in die Zeit", "Historical context"), unter: LT("Sechs Leseschlüssel zum Alltag von 1899", "Six perspectives on everyday life in 1899"), symbol: "clock") { nav.open(.lernen("kontext", "")) }
            Text(LT("Dein Lernstand bleibt auf diesem Gerät. Öffnen einer Buchseite zählt hier noch nicht als gelöste Aufgabe.", "Learning progress stays on this device. Opening a book page does not count as completing an activity.")).font(Schrift.meta).foregroundStyle(Theme.leise)
        }
    }
}

struct GlossarView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    @EnvironmentObject private var progress: ProgressStore
    @State private var suche = ""
    @State private var nurGemerkt = false
    private var begriffe: [LernBegriff] {
        repo.lernen.begriffe.filter { b in
            (!nurGemerkt || progress.lern.gemerkt.contains(b.id)) && (suche.isEmpty || LernInhalte.normal(([b.titel,b.text] + b.formen).joined(separator: " ")).contains(LernInhalte.normal(suche)))
        }.sorted { $0.titel.localizedStandardCompare($1.titel) == .orderedAscending }
    }
    var body: some View {
        LernSeite(titel: LT("Wörter verstehen", "Understand words")) {
            RedaktionHinweis()
            Text(LT("Dieses Glossar wurde für die App ergänzt. Es ersetzt nicht das in der Vorlage fehlende Wörterverzeichnis des Buches.", "This glossary was added for the app. It does not reconstruct the book’s missing word list.")).font(Schrift.meta).foregroundStyle(Theme.leise)
            Picker(LT("Auswahl", "Filter"), selection: $nurGemerkt) {
                Text(LT("Alle", "All")).tag(false)
                Text(LT("Gemerkt", "Saved")).tag(true)
            }.pickerStyle(.segmented)
            if begriffe.isEmpty {
                ContentUnavailableView(LT("Keine Begriffe", "No terms"), systemImage: "bookmark", description: Text(LT("Ändere die Suche oder merke einen Begriff mit dem Lesezeichen.", "Change the search or save a term with the bookmark button.")))
            }
            ForEach(begriffe) { b in
                StartKachel(titel: b.titel, unter: b.text, symbol: progress.lern.gemerkt.contains(b.id) ? "bookmark.fill" : "text.magnifyingglass") { nav.open(.lernen("begriff", b.id)) }.accessibilityIdentifier("term.\(b.id)")
            }
        }
        .searchable(text: $suche, placement: .navigationBarDrawer(displayMode: .always), prompt: LT("Begriff oder Schreibweise", "Term or spelling"))
    }
}

struct BegriffView: View {
    let begriff: LernBegriff
    var body: some View {
        LernSeite(titel: begriff.titel) { BegriffInhalt(begriff: begriff) }
    }
}

struct BegriffInhalt: View {
    let begriff: LernBegriff
    var oeffnen: ((Route) -> Void)? = nil
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var repo: ContentRepository
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RedaktionHinweis()
            LernText(text: begriff.titel, id: "begriff-wort-\(begriff.id)")
            LernText(text: begriff.text, id: "begriff-\(begriff.id)")
            LernText(text: begriff.anwendung, id: "beispiel-\(begriff.id)")
            if begriff.quelle.art == "tafel", let t = repo.tafel(begriff.quelle.id), let img = repo.bild(t.bild) {
                ZoomBild(image: img).frame(height: 260).accessibilityLabel(t.titel)
            }
            Button { progress.begriffMerken(begriff.id) } label: {
                Label(progress.lern.gemerkt.contains(begriff.id) ? LT("Gemerkt – entfernen", "Saved — remove") : LT("Begriff merken", "Save term"), systemImage: progress.lern.gemerkt.contains(begriff.id) ? "bookmark.fill" : "bookmark").frame(minHeight: 44)
            }.accessibilityIdentifier("term.save")
            QuellenKnopf(quelle: begriff.quelle, mitZitat: true, oeffnen: oeffnen)
        }.font(Schrift.text).foregroundStyle(Theme.tinte)
    }
}

struct KontextView: View {
    let id: String
    @EnvironmentObject private var repo: ContentRepository
    var body: some View {
        LernSeite(titel: LT("Einblicke in die Zeit", "Historical context")) {
            RedaktionHinweis()
            ForEach(repo.lernen.kontexte.filter { id.isEmpty || $0.id == id }) { k in
                Karte {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(k.titel).font(Schrift.abschnitt)
                        LernText(text: k.text, id: k.id)
                        QuellenKnopf(quelle: k.quelle, mitZitat: true)
                    }
                }
            }
        }
    }
}
