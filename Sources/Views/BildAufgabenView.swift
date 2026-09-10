import SwiftUI

struct GedeckAnordnung {
    static let loesung = ["links": "Gabel", "oben": "Löffel", "rechts": "Messer"]
    private(set) var plaetze: [String: String] = [:]
    var vollstaendig: Bool { plaetze.count == 3 }
    var richtig: Bool { plaetze == Self.loesung }
    mutating func lege(_ teil: String, nach platz: String) {
        guard Self.loesung.keys.contains(platz), Self.loesung.values.contains(teil) else { return }
        plaetze = plaetze.filter { $0.value != teil }
        plaetze[platz] = teil
    }
}

struct BildAufgabenListe: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    @EnvironmentObject private var progress: ProgressStore
    var body: some View {
        LernSeite(titel: LT("Mit Bildern lernen", "Learn with pictures")) {
            Text(LT("Schau auf Form und Anordnung. Nach jeder Aufgabe kannst du die vollständige Tafel zum Vergleich öffnen.", "Look at the shapes and arrangement. After each activity you can compare the complete plate.")).font(Schrift.text)
            ForEach(repo.lernen.bildaufgaben) { a in
                StartKachel(titel: a.titel, unter: a.quelle.titel, symbol: progress.lern.uebungen.contains(a.id) ? "checkmark.circle" : "fork.knife") { nav.open(.lernen("bild", a.id)) }.accessibilityIdentifier("image-task.\(a.id)")
            }
        }
    }
}

struct BildAufgabeView: View {
    let aufgabe: BildAufgabe
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var progress: ProgressStore
    @State private var gewaehlt: Int?
    @State private var teil = "Gabel"
    @State private var gedeck = GedeckAnordnung()
    @State private var geprueft = false
    @ScaledMetric(relativeTo: .body) private var besteckBreite = 100.0
    private var korrekt: Bool { aufgabe.art == "anordnen" ? gedeck.richtig : gewaehlt == aufgabe.richtig }

    var body: some View {
        LernSeite(titel: aufgabe.titel) {
            LernText(text: aufgabe.text, id: "bild-\(aufgabe.id)")
            if aufgabe.art == "anordnen" { anordnen } else { ausschnitte }
            if geprueft {
                Label(korrekt ? LT("Gut erkannt", "Well spotted") : LT("Vergleiche noch einmal", "Take another look"), systemImage: korrekt ? "checkmark.circle" : "eye")
                    .font(Schrift.abschnitt).foregroundStyle(korrekt ? Theme.erfolg : Theme.akzent).accessibilityIdentifier("image.feedback")
                LernText(text: aufgabe.erklaerung, id: "bild-erklaerung")
                if let img = repo.bild(aufgabe.bild) { ZoomBild(image: img).frame(height: 360).accessibilityLabel(aufgabe.quelle.titel) }
                PrimaerKnopf(titel: LT("Noch einmal probieren", "Try again"), symbol: "arrow.counterclockwise") { gewaehlt = nil; geprueft = false; gedeck = GedeckAnordnung(); teil = "Gabel" }
            }
            QuellenKnopf(quelle: aufgabe.quelle)
        }
    }

    private var ausschnitte: some View {
        VStack(spacing: 16) {
            ForEach(Array(aufgabe.optionen.enumerated()), id: \.offset) { i, o in
                Button {
                    guard !geprueft else { return }
                    gewaehlt = i; pruefen()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(o.titel).font(Schrift.abschnitt)
                            Spacer()
                            if geprueft && i == aufgabe.richtig { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.erfolg) }
                            else if gewaehlt == i { Image(systemName: "arrow.counterclockwise.circle").foregroundStyle(Theme.fehler) }
                        }
                        if let img = ausschnitt(o) {
                            Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 150).accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(Theme.tinte).padding(16).background(Theme.flaeche, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(geprueft && i == aufgabe.richtig ? Theme.erfolg : Theme.linie, lineWidth: 2))
                }.buttonStyle(.plain).disabled(geprueft)
                    .accessibilityLabel(o.titel + ": " + o.beschreibung)
                    .accessibilityIdentifier("image.answer.\(i)")
            }
        }
    }

    private var anordnen: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LT("1. Besteckteil wählen", "1. Choose an item")).font(Schrift.zeile)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: besteckBreite))], spacing: 8) {
                ForEach(["Gabel", "Messer", "Löffel"], id: \.self) { t in
                    Button { teil = t; geprueft = false } label: {
                        Text(t).font(Schrift.zeile).frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(teil == t ? Theme.aufAkzent : Theme.tinte)
                            .background(teil == t ? Theme.akzent : Theme.weich, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityAddTraits(teil == t ? [.isSelected] : [])
                        .accessibilityIdentifier("place.item.\(t)")
                }
            }
            Text(LT("2. Platz am Teller antippen", "2. Tap a place by the plate")).font(Schrift.zeile)
            VStack(spacing: 12) {
                platz("oben", LT("Oberhalb", "Above"))
                HStack(spacing: 10) {
                    platz("links", LT("Links", "Left"))
                    ZStack {
                        Circle().fill(Theme.flaeche).overlay(Circle().stroke(Theme.linie, lineWidth: 2))
                        Text(LT("Teller", "Plate")).font(Schrift.klein).lineLimit(1).minimumScaleFactor(0.4)
                    }.frame(width: 64, height: 64).accessibilityHidden(true)
                    platz("rechts", LT("Rechts", "Right"))
                }
            }
            PrimaerKnopf(titel: LT("Anordnung prüfen", "Check arrangement"), symbol: "checkmark") { pruefen() }
                .disabled(!gedeck.vollstaendig).opacity(gedeck.vollstaendig ? 1 : 0.5).accessibilityIdentifier("place.check")
        }
    }
    private func platz(_ id: String, _ titel: String) -> some View {
        Button { gedeck.lege(teil, nach: id); geprueft = false } label: {
            VStack(spacing: 5) {
                Text(titel).font(Schrift.klein).foregroundStyle(Theme.leise)
                Text(gedeck.plaetze[id] ?? LT("Ablegen", "Place here")).font(Schrift.zeile)
            }
            .padding(10).frame(maxWidth: .infinity, minHeight: 70).background(Theme.flaeche, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.linie))
        }.buttonStyle(.plain).accessibilityLabel(titel + ": " + (gedeck.plaetze[id] ?? LT("leer", "empty")))
            .accessibilityHint(LT("Legt das ausgewählte Besteckteil hier ab.", "Places the selected item here."))
            .accessibilityIdentifier("place.slot.\(id)")
    }
    private func pruefen() {
        geprueft = true
        if korrekt { progress.uebung(aufgabe.id) }
    }
    private func ausschnitt(_ o: BildOption) -> UIImage? {
        guard o.crop.count == 4, let img = repo.bild(aufgabe.bild), let cg = img.cgImage else { return nil }
        let w = Double(cg.width), h = Double(cg.height)
        let r = CGRect(x: o.crop[0] * w, y: o.crop[1] * h, width: o.crop[2] * w, height: o.crop[3] * h)
        guard let crop = cg.cropping(to: r) else { return nil }
        return UIImage(cgImage: crop)
    }
}
