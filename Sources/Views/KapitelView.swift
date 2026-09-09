import SwiftUI

/// Lesen eines Kapitels: Seiten nach Original-Paginierung, Schrift alt/neu, Vorlesen mit Markierung, Wort-Lupe.
struct KapitelView: View {
    let kapitel: Kapitel
    var startSeite: String? = nil
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var nav: Navigator
    @StateObject private var vorleser = Vorleser()
    @State private var alt = true
    @State private var lupe: Lupe?
    @State private var geladen = false

    struct Lupe: Identifiable {
        let id = UUID()
        let neu: String
        let alt: String
        let wort: VorleseDaten.Wort?
        let teil: Int
    }

    private var groesse: CGFloat { CGFloat(settings.fontSize) }
    private var index: Int { repo.kapitel.firstIndex(of: kapitel) ?? 0 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    kopf
                    ForEach(Array(kapitel.seiten.enumerated()), id: \.offset) { si, seite in
                        seitenAnsicht(si, seite)
                            .id("seite-\(seite.nr)")
                    }
                    fuss
                }
                .frame(maxWidth: Theme.leseBreite)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.seite)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .environment(\.leseMarkierung, vorleser.markierung)
            .onChange(of: vorleser.markierung?.block) { _, _ in
                guard let m = vorleser.markierung, kapitel.seiten.indices.contains(m.seite) else { return }
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo("block-\(m.seite)-\(m.block)", anchor: .center) }
            }
            .onAppear {
                guard !geladen else { return }
                geladen = true
                alt = Launch.alt ?? settings.altSchrift
                ladeAudio()
                if let s = startSeite ?? Launch.seite, kapitel.seiten.contains(where: { $0.nr == s }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo("seite-\(s)", anchor: .top) }
                }
                if Launch.vorlesen { vorleser.start() }
            }
        }
        .navigationTitle(kapitel.nummer.isEmpty ? kapitel.titel : kapitel.nummer)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { SchriftUmschalter(alt: $alt) }
            ToolbarItem(placement: .topBarTrailing) { groessenMenue }
        }
        .safeAreaInset(edge: .bottom) {
            if vorleser.bereit { VorleseZeile(vorleser: vorleser) }
        }
        .sheet(item: $lupe) { l in WortLupe(lupe: l, vorleser: vorleser) }
        .onDisappear { vorleser.stop() }
        .tint(Theme.akzent)
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !kapitel.nummer.isEmpty {
                Text(kapitel.nummer).font(Schrift.eyebrow).foregroundStyle(Theme.akzent)
            }
            Text(alt ? Fraktur.titel(kapitel.titel) : kapitel.titel)
                .font(Schrift.leseFett(groesse * 1.35, alt: alt))
                .foregroundStyle(Theme.tinte)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(kapitel.titel)
            Text(T("chapter.pages", kapitel.seiten.count, max(1, kapitel.woerter / 130)))
                .font(Schrift.meta).foregroundStyle(Theme.leise)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func seitenAnsicht(_ si: Int, _ seite: Seite) -> some View {
        VStack(alignment: .leading, spacing: groesse * 0.75) {
            HStack {
                Rectangle().fill(Theme.linie).frame(height: 1)
                Text(T("chapter.page", seite.nr)).font(Schrift.klein).foregroundStyle(Theme.leise).fixedSize()
                Rectangle().fill(Theme.linie).frame(height: 1)
            }
            .padding(.top, groesse)
            .padding(.bottom, groesse * 0.4)
            .accessibilityAddTraits(.isHeader)
            .onAppear { progress.position(kapitel, seite: seite.nr); if si == kapitel.seiten.count - 1 { progress.kapitelGelesen(kapitel) } }
            ForEach(Array(seite.bloecke.enumerated()), id: \.offset) { bi, block in
                BlockView(block: block, seite: si, index: bi, alt: alt) { b, item, zeichen in
                    wortTippen(seite: si, block: b, item: item, zeichen: zeichen)
                }
                .id("block-\(si)-\(bi)")
            }
        }
    }

    private var fuss: some View {
        VStack(spacing: 12) {
            Divider().padding(.top, 30)
            if progress.istGelesen(kapitel) {
                Label(T("chapter.done"), systemImage: "checkmark.circle.fill").font(Schrift.meta).foregroundStyle(Theme.erfolg)
            }
            HStack(spacing: 12) {
                if let v = repo.vorheriges(vor: kapitel.slug) {
                    Button { nav.ersetzeKapitel(v) } label: {
                        Label(T("chapter.prev"), systemImage: "chevron.left").font(Schrift.knopf)
                            .frame(maxWidth: .infinity, minHeight: Theme.knopfHoehe)
                    }
                    .buttonStyle(.bordered)
                }
                if let n = repo.naechstes(nach: kapitel.slug) {
                    PrimaerKnopf(titel: T("chapter.next"), symbol: "chevron.right") { nav.ersetzeKapitel(n) }
                }
            }
        }
        .padding(.top, 10)
    }

    private var groessenMenue: some View {
        Menu {
            Section(T("settings.textsize")) {
                ForEach([16, 18, 20, 22, 24, 28], id: \.self) { g in
                    Button { settings.fontSize = Double(g) } label: {
                        if Int(settings.fontSize) == g { Label(T("settings.pt", g), systemImage: "checkmark") } else { Text(T("settings.pt", g)) }
                    }
                }
            }
            Section(T("settings.spacing")) {
                ForEach(Settings.zeilenFaktoren, id: \.self) { f in
                    Button { settings.lineFactor = f } label: {
                        let t = String(format: "%.1f", locale: Locale(identifier: L10n.lang), f)
                        if settings.lineFactor == f { Label(t, systemImage: "checkmark") } else { Text(t) }
                    }
                }
            }
        } label: {
            Text("Aa").font(Schrift.bold(17)).frame(minWidth: Theme.mindestTouch, minHeight: Theme.mindestTouch)
        }
        .accessibilityLabel(T("settings.textsize"))
    }

    private func ladeAudio() {
        let teile = repo.audioTeile(kapitel).compactMap { t -> VorleseTeil? in
            guard let url = repo.audioURL(t.stem), let d = repo.vorleseDaten(t.stem) else { return nil }
            return VorleseTeil(url: url, daten: d)
        }
        vorleser.laden(teile)
    }

    /// Tipp auf ein Wort: Wortgrenzen im Blocktext suchen, Lupe mit Antiqua + Fraktur + Audio-Ausschnitt.
    private func wortTippen(seite si: Int, block bi: Int, item: Int, zeichen: Int) {
        guard kapitel.seiten.indices.contains(si), kapitel.seiten[si].bloecke.indices.contains(bi) else { return }
        let b = kapitel.seiten[si].bloecke[bi]
        let quelle: Block = item >= 0 ? (b.items ?? [])[safe: item] ?? b : b
        let textAlt = quelle.text(alt: true), textNeu = quelle.text(alt: false)
        let text = alt ? textAlt : textNeu
        guard let r = Fraktur.wortBereich(in: text, um: zeichen) else { return }
        let wortAnzeige = String(text[r])
        let treffer = vorleser.wort(seite: si, block: bi, item: item, zeichen: zeichen, alt: alt)
        var neu = alt ? Fraktur.entfrakturisieren(wortAnzeige) : wortAnzeige
        var altWort = alt ? wortAnzeige : Fraktur.titel(wortAnzeige)
        if let (_, w) = treffer {
            let seg = textNeu, segAlt = textAlt
            if w.a < w.e, w.e <= seg.count { neu = String(seg[seg.index(seg.startIndex, offsetBy: w.a)..<seg.index(seg.startIndex, offsetBy: w.e)]) }
            if let aa = w.aa, let ae = w.ae, aa < ae, ae <= segAlt.count { altWort = String(segAlt[segAlt.index(segAlt.startIndex, offsetBy: aa)..<segAlt.index(segAlt.startIndex, offsetBy: ae)]) }
        }
        lupe = Lupe(neu: neu, alt: altWort, wort: treffer?.1, teil: treffer?.0 ?? 0)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// Wort-Lupe: das angetippte Wort groß in neuer Schrift, darunter in Fraktur, mit Anhören.
struct WortLupe: View {
    let lupe: KapitelView.Lupe
    @ObservedObject var vorleser: Vorleser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Text(T("lupe.title")).font(Schrift.eyebrow).foregroundStyle(Theme.akzent)
            Text(lupe.neu).font(Schrift.bold(40)).foregroundStyle(Theme.tinte).minimumScaleFactor(0.5).lineLimit(2).multilineTextAlignment(.center)
            Text(lupe.alt).font(Schrift.fraktur(34)).foregroundStyle(Theme.leise).minimumScaleFactor(0.5).lineLimit(2).multilineTextAlignment(.center)
            if let w = lupe.wort {
                PrimaerKnopf(titel: T("lupe.play"), symbol: "speaker.wave.2.fill") { vorleser.spieleWort(w, teil: lupe.teil) }
                    .frame(maxWidth: 260)
            }
            Button(T("common.done")) { dismiss() }.font(Schrift.knopf).tint(Theme.akzent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .presentationDetents([.height(340)])
        .onAppear { if let w = lupe.wort { vorleser.spieleWort(w, teil: lupe.teil) } }
    }
}

/// Vorlese-Leiste: Play/Pause, Fortschritt, Tempo.
struct VorleseZeile: View {
    @ObservedObject var vorleser: Vorleser

    var body: some View {
        HStack(spacing: 14) {
            Button { vorleser.umschalten() } label: {
                Image(systemName: vorleser.laeuft ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40)).foregroundStyle(Theme.akzent)
                    .frame(minWidth: Theme.mindestTouch, minHeight: Theme.mindestTouch)
            }
            .accessibilityLabel(vorleser.laeuft ? T("read.pause") : T("read.play"))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(T("read.aloud")).font(Schrift.zeile).foregroundStyle(Theme.tinte)
                    if vorleser.teileAnzahl > 1 {
                        Text(T("read.part", vorleser.teilIndex + 1, vorleser.teileAnzahl)).font(Schrift.klein).foregroundStyle(Theme.leise)
                    }
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.weich)
                        Capsule().fill(Theme.akzent).frame(width: max(0, g.size.width * vorleser.fortschritt))
                    }
                }
                .frame(height: 4)
            }
            Button { vorleser.naechsteRate() } label: {
                Text(vorleser.rateText + "×").font(Schrift.bold(15)).foregroundStyle(Theme.akzent)
                    .frame(minWidth: Theme.mindestTouch, minHeight: Theme.mindestTouch)
                    .background(Theme.weich, in: Capsule())
            }
            .accessibilityLabel(T("read.rate") + " " + vorleser.rateText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// Kleine Hilfen zur Fraktur im Swift-Code (die eigentliche Ableitung passiert im Build, tools/fraktur.py).
enum Fraktur {
    /// Titel/Einzelwörter ohne Build-Ableitung: einfache ſ-Regel (s vor Buchstabe außer am Wortende), reicht für Kapiteltitel.
    static func titel(_ s: String) -> String {
        var out = ""
        let chars = Array(s)
        for (i, c) in chars.enumerated() {
            if c == "s", i + 1 < chars.count, chars[i + 1].isLetter, !(chars[i + 1] == "s" && (i + 2 >= chars.count || !chars[i + 2].isLetter)) {
                out.append("ſ")
            } else {
                out.append(c)
            }
        }
        return out.replacingOccurrences(of: "etc.", with: "ꝛc.")
    }

    static func entfrakturisieren(_ s: String) -> String {
        s.replacingOccurrences(of: "ſ", with: "s").replacingOccurrences(of: "ꝛc.", with: "etc.")
    }

    /// Wortgrenzen um eine Zeichenposition (Buchstaben, Ziffern, Bindestrich innerhalb, Apostroph).
    static func wortBereich(in text: String, um pos: Int) -> Range<String.Index>? {
        guard pos < text.count else { return nil }
        let chars = Array(text)
        func istWort(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "ꝛ" || c == "ſ" || c == "’" || c == "'" }
        guard istWort(chars[pos]) else { return nil }
        var a = pos, e = pos
        while a > 0 && (istWort(chars[a - 1]) || (chars[a - 1] == "-" && a > 1 && istWort(chars[a - 2]))) { a -= 1 }
        while e + 1 < chars.count && (istWort(chars[e + 1]) || (chars[e + 1] == "-" && e + 2 < chars.count && istWort(chars[e + 2]))) { e += 1 }
        return text.index(text.startIndex, offsetBy: a)..<text.index(text.startIndex, offsetBy: e + 1)
    }
}
