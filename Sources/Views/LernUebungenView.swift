import SwiftUI

struct FragenAuswahlView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var nav: Navigator
    var body: some View {
        LernSeite(titel: LT("Zum Kapitel nachdenken", "Chapter questions")) {
            Text(LT("Je drei Fragen zum Buchtext. Nach deiner Antwort erklären wir die Stelle. Es gibt keinen Zeitdruck.", "Three questions per chapter. Each answer is followed by an explanation. Take your time.")).font(Schrift.text)
            if !progress.lern.wiederholen.isEmpty {
                StartKachel(titel: LT("Noch einmal ansehen", "Review again"), unter: "\(progress.lern.wiederholen.count) " + LT("Fragen", "questions"), symbol: "arrow.counterclockwise") { nav.open(.lernen("fragen", "wiederholen")) }
            }
            ForEach(repo.kapitel.filter { k in repo.lernen.fragen.contains { $0.kapitel == k.slug } }) { k in
                let fragen = repo.lernen.fragen.filter { $0.kapitel == k.slug }
                let anzahl = fragen.filter { progress.lern.beantwortet.contains($0.id) }.count
                StartKachel(titel: k.name, unter: "\(anzahl)/\(fragen.count) " + LT("beantwortet", "answered"), symbol: "questionmark.bubble") { nav.open(.lernen("fragen", k.slug)) }.accessibilityIdentifier("questions.\(k.slug)")
            }
        }
    }
}

struct KapitelFragenView: View {
    let auswahl: String
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var stimme: LernStimme
    @State private var fragen: [LernFrage] = []
    @State private var geladen = false
    @State private var index = 0
    @State private var antwort: Int?
    @State private var richtig = 0
    private var aktuelle: LernFrage? { fragen[safe: index] }
    var body: some View {
        LernSeite(titel: LT("Zum Kapitel nachdenken", "Chapter questions")) {
            if let f = aktuelle {
                Text("\(index + 1) / \(fragen.count)").font(Schrift.eyebrow).foregroundStyle(Theme.akzent)
                Text(LT("Nach dem Buch von 1899", "According to the 1899 book")).font(Schrift.meta).foregroundStyle(Theme.leise)
                LernText(text: f.frage, id: f.id)
                ForEach(Array(f.antworten.enumerated()), id: \.offset) { i, text in
                    Button { waehlen(i, frage: f) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text(text).font(Schrift.text).multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            if antwort != nil && i == f.richtig { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.erfolg) }
                            else if antwort == i { Image(systemName: "arrow.counterclockwise.circle").foregroundStyle(Theme.fehler) }
                        }
                        .foregroundStyle(Theme.tinte).padding(16).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(antwort == nil ? Theme.flaeche : (i == f.richtig ? Theme.erfolg.opacity(0.13) : Theme.flaeche), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.linie))
                    }.buttonStyle(.plain).disabled(antwort != nil).accessibilityIdentifier("answer.\(i)")
                }
                if let a = antwort {
                    Label(a == f.richtig ? LT("Richtig verstanden", "You understood it") : LT("Schauen wir in den Text", "Let’s look at the text"), systemImage: a == f.richtig ? "checkmark.circle" : "book.pages")
                        .font(Schrift.zeile).foregroundStyle(a == f.richtig ? Theme.erfolg : Theme.akzent).accessibilityIdentifier("question.feedback")
                    LernText(text: f.erklaerung, id: "erklaerung-\(f.id)")
                    QuellenKnopf(quelle: f.quelle, mitZitat: true)
                    if a != f.richtig {
                        Text(LT("Diese Frage liegt jetzt unter „Noch einmal ansehen“.", "This question is now saved under “Review again”.")).font(Schrift.meta)
                    }
                    PrimaerKnopf(titel: index + 1 < fragen.count ? LT("Nächste Frage", "Next question") : LT("Runde abschließen", "Finish round"), symbol: "chevron.right") {
                        stimme.stop(); antwort = nil; index += 1
                    }.accessibilityIdentifier("question.next")
                }
            } else if geladen {
                SeitenKopf(titel: fragen.isEmpty ? LT("Alles angesehen", "All reviewed") : LT("Runde abgeschlossen", "Round complete"), untertitel: fragen.isEmpty ? LT("Hier sind gerade keine Fragen zum Wiederholen.", "There are no questions to review right now.") : "\(richtig) / \(fragen.count) " + LT("beim ersten Versuch richtig", "correct on the first try"))
                if !fragen.isEmpty {
                    Text(LT("Du kannst jede Buchstelle erneut lesen und die Fragen jederzeit wiederholen.", "You can reread any passage and repeat the questions whenever you like.")).font(Schrift.text)
                    PrimaerKnopf(titel: LT("Noch eine Runde", "Another round"), symbol: "arrow.counterclockwise") { start() }.accessibilityIdentifier("question.again")
                }
            }
        }
        .onAppear { if !geladen { start() } }
    }
    private func start() {
        // Momentaufnahme: richtige Antworten dürfen eine laufende Wiederholungsrunde nicht verkürzen.
        fragen = repo.lernen.fragen.filter { auswahl == "wiederholen" ? progress.lern.wiederholen.contains($0.id) : $0.kapitel == auswahl }
        index = 0; antwort = nil; richtig = 0; geladen = true
    }
    private func waehlen(_ a: Int, frage: LernFrage) {
        guard antwort == nil else { return }
        stimme.stop(); antwort = a
        let korrekt = a == frage.richtig
        if korrekt { richtig += 1 }
        progress.frage(frage.id, richtig: korrekt)
    }
}

struct TourView: View {
    let tour: LernTour
    @EnvironmentObject private var nav: Navigator
    @EnvironmentObject private var progress: ProgressStore
    private func fertig(_ s: LernSchritt) -> Bool { progress.lern.tourSchritte.contains("\(tour.id)/\(s.id)") }
    private var abgeschlossen: Int { tour.schritte.filter(fertig).count }
    var body: some View {
        LernSeite(titel: tour.titel) {
            SeitenKopf(titel: tour.titel, untertitel: tour.text)
            Text("\(abgeschlossen)/\(tour.schritte.count) · \(tour.dauer)").font(Schrift.meta)
            ProgressView(value: Double(abgeschlossen), total: Double(tour.schritte.count)).accessibilityLabel(LT("Tourfortschritt", "Tour progress"))
            if let naechster = tour.schritte.first(where: { !fertig($0) }) {
                PrimaerKnopf(titel: LT("Weiter: ", "Continue: ") + naechster.titel, symbol: "arrow.right") { nav.open(naechster.ziel.route) }.accessibilityIdentifier("tour.continue")
            } else {
                Label(LT("Du hast die Tour abgeschlossen", "You completed the tour"), systemImage: "checkmark.seal").font(Schrift.abschnitt).foregroundStyle(Theme.erfolg)
            }
            Text(LT("Öffne eine Station und kehre mit „Zurück“ hierher zurück. Markiere sie als erledigt, wenn du sie angesehen hast.", "Open a stop, then use Back to return. Mark it complete after you have explored it.")).font(Schrift.meta).foregroundStyle(Theme.leise)
            ForEach(Array(tour.schritte.enumerated()), id: \.element.id) { i, s in
                Karte {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(i + 1). \(s.titel)").font(Schrift.abschnitt)
                        LernText(text: s.text, id: "tour-\(s.id)")
                        Button { nav.open(s.ziel.route) } label: { Label(LT("Station öffnen", "Open stop"), systemImage: "arrow.up.right").frame(minHeight: 44) }
                        Toggle(LT("Erledigt", "Complete"), isOn: Binding(get: { fertig(s) }, set: { progress.schritt(s.id, tour: tour.id, fertig: $0) }))
                            .font(Schrift.zeile).accessibilityIdentifier("tour.done.\(s.id)")
                    }
                }
            }
        }
    }
}

struct LeseUebungenView: View {
    let start: String
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var stimme: LernStimme
    @State private var stufe = "gruppe"
    @State private var aufgedeckt: Set<String> = []
    @State private var gestartet = false
    var body: some View {
        LernSeite(titel: LT("Wortgruppen & Sätze", "Phrases & sentences")) {
            Text(LT("Lies zuerst die alte Schrift. Vergleiche dann mit der neuen Schrift und höre den Text an. Die Beispiele stammen aus der Buchfassung dieser App.", "Read the Fraktur text first. Then reveal the modern type and listen. These examples come from the book text in this app.")).font(Schrift.text)
            Picker(LT("Übungsstufe", "Exercise level"), selection: $stufe) {
                Text(LT("Wortgruppen", "Phrases")).tag("gruppe")
                Text(LT("Sätze", "Sentences")).tag("satz")
            }.pickerStyle(.segmented).onChange(of: stufe) { _, _ in stimme.stop() }
            ForEach(repo.lernen.leseuebungen.filter { $0.stufe == stufe }) { u in
                Karte {
                    VStack(alignment: .leading, spacing: 12) {
                        LernText(text: u.neu, id: u.id, alt: u.alt, antiqua: u.antiqua, map: u.map)
                        Button { if aufgedeckt.contains(u.id) { aufgedeckt.remove(u.id) } else { aufgedeckt.insert(u.id) } } label: {
                            Label(aufgedeckt.contains(u.id) ? LT("Neue Schrift ausblenden", "Hide modern type") : LT("Neue Schrift zeigen", "Show modern type"), systemImage: "textformat").frame(minHeight: 44)
                        }.accessibilityIdentifier("reveal.\(u.id)")
                        if aufgedeckt.contains(u.id) {
                            Text(u.neu).font(Schrift.text).accessibilityIdentifier("revealed.\(u.id)")
                            Button { progress.uebung(u.id) } label: {
                                Label(progress.lern.uebungen.contains(u.id) ? LT("Geübt", "Practised") : LT("Als geübt merken", "Mark as practised"), systemImage: progress.lern.uebungen.contains(u.id) ? "checkmark.circle.fill" : "checkmark.circle").frame(minHeight: 44)
                            }
                        }
                        QuellenKnopf(quelle: u.quelle)
                    }
                }
            }
        }.onAppear { if !gestartet { stufe = start == "satz" ? "satz" : "gruppe"; gestartet = true } }
    }
}

struct MenuFuehrerView: View {
    let menu: MenuFuehrer
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    var body: some View {
        LernSeite(titel: menu.titel) {
            RedaktionHinweis()
            LernText(text: menu.text, id: "menu-intro")
            if let img = repo.bild(menu.menu) { ZoomBild(image: img).frame(height: 320).accessibilityLabel(menu.quelle.titel) }
            QuellenKnopf(quelle: menu.quelle)
            ForEach(menu.abschnitte) { a in
                Karte {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(a.titel).font(Schrift.abschnitt)
                        LernText(text: a.zitat, id: "menuezeile-\(a.id)", sprache: a.sprache)
                        LernText(text: a.text, id: a.id)
                    }
                }
            }
            Text(LT("Worterklärungen nachschlagen", "Word references")).font(Schrift.meta)
            ForEach(menu.links, id: \.url) { l in
                if let url = URL(string: l.url) { Link(l.titel, destination: url).font(Schrift.meta).frame(minHeight: 44) }
            }
            StartKachel(titel: LT("Andere Karten vergleichen", "Compare other menus"), unter: LT("Zur Sammlung der Menüs und Tischkarten", "Open the menu and place-card collection"), symbol: "list.bullet.rectangle") { nav.open(.menus) }
        }
    }
}
