import AVFoundation
import SwiftUI

/// Wortzeiten aus tools/build_audio.py (edge-tts WordBoundary).
struct VorleseDaten: Codable {
    struct Segment: Codable { let seite: Int; let block: Int; let item: Int; let text: String }
    /// a/e: Zeichenbereich in `neu`, aa/ae: in `alt`; p = Satzende (. ! ?) nach dem Wort
    struct Wort: Codable { let s: Int; let a: Int; let e: Int; let aa: Int?; let ae: Int?; let t: Int; let d: Int; let p: Bool? }
    let voice: String
    let duration: Int
    let segments: [Segment]
    let words: [Wort]
}

/// Aktuell gelesene Stelle: Seite/Block/Listenpunkt und Zeichenbereich in beiden Schriften.
struct LeseMarkierung: Equatable {
    let seite: Int
    let block: Int
    let item: Int
    let neu: Range<Int>
    let alt: Range<Int>
    func bereich(alt altSchrift: Bool) -> Range<Int> { altSchrift ? alt : neu }
}

private struct LeseMarkierungKey: EnvironmentKey {
    static let defaultValue: LeseMarkierung? = nil
}

extension EnvironmentValues {
    var leseMarkierung: LeseMarkierung? {
        get { self[LeseMarkierungKey.self] }
        set { self[LeseMarkierungKey.self] = newValue }
    }
}

/// Ein Audioteil (Kapitel sind in ≤ 10-min-Dateien geteilt).
struct VorleseTeil {
    let url: URL
    let daten: VorleseDaten
}

/// Vorlesestimme mit Wortmarkierung: spielt die gebündelten Audiodateien und hebt beim Lesen
/// ein bis drei Wörter hervor, je nach Sprechtempo (Fenster ~0,6 s, nie über einen Punkt oder Absatz hinaus).
@MainActor
final class Vorleser: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var laeuft = false
    @Published private(set) var fortschritt: Double = 0
    @Published private(set) var markierung: LeseMarkierung?
    @Published private(set) var rate: Float = 1.0
    @Published private(set) var bereit = false
    @Published private(set) var teilIndex = 0

    static let raten: [Float] = [0.8, 1.0, 1.2]
    private var teile: [VorleseTeil] = []
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var zuletzt = 0
    private var wortPlayer: AVAudioPlayer?
    private var wortTimer: Timer?

    var teileAnzahl: Int { teile.count }
    var daten: VorleseDaten? { teile.indices.contains(teilIndex) ? teile[teilIndex].daten : nil }

    var rateText: String {
        let s = String(format: "%.1f", locale: Locale(identifier: L10n.lang), rate)
        return s.hasSuffix("0") || s.hasSuffix(",0") ? String(Int(rate.rounded())) : s
    }

    func laden(_ teile: [VorleseTeil]) {
        stop()
        self.teile = teile
        teilIndex = 0
        bereit = !teile.isEmpty && ladeTeil(0)
    }

    @discardableResult
    private func ladeTeil(_ i: Int) -> Bool {
        guard teile.indices.contains(i) else { return false }
        do {
            let p = try AVAudioPlayer(contentsOf: teile[i].url)
            p.enableRate = true
            p.delegate = self
            p.prepareToPlay()
            player = p
            teilIndex = i
            zuletzt = 0
            return true
        } catch {
            return false
        }
    }

    func umschalten() { laeuft ? pause() : start() }

    func start() {
        guard let p = player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        p.rate = rate
        p.play()
        laeuft = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Ab einer bestimmten Stelle (Seite/Block) vorlesen – Tipp auf einen Absatz.
    func start(seite: Int, block: Int) {
        for (i, teil) in teile.enumerated() {
            if let w = teil.daten.words.first(where: { let s = teil.daten.segments[$0.s]; return s.seite == seite && s.block == block }) {
                if i != teilIndex { pause(); ladeTeil(i) }
                player?.currentTime = Double(w.t) / 1000
                zuletzt = 0
                start()
                return
            }
        }
    }

    func pause() {
        player?.pause()
        laeuft = false
        timer?.invalidate()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        laeuft = false
        timer?.invalidate()
        markierung = nil
        fortschritt = 0
        zuletzt = 0
    }

    func naechsteRate() {
        let i = Vorleser.raten.firstIndex(of: rate) ?? 1
        rate = Vorleser.raten[(i + 1) % Vorleser.raten.count]
        player?.rate = rate
    }

    /// Ein einzelnes Wort abspielen (Wort-Lupe): Ausschnitt t…t+d aus der Datei.
    func spieleWort(_ wort: VorleseDaten.Wort, teil: Int) {
        guard teile.indices.contains(teil) else { return }
        wortTimer?.invalidate()
        wortPlayer?.stop()
        guard let p = try? AVAudioPlayer(contentsOf: teile[teil].url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        p.currentTime = max(0, Double(wort.t) / 1000 - 0.03)
        p.play()
        wortPlayer = p
        let dauer = Double(wort.d) / 1000 + 0.12
        wortTimer = Timer.scheduledTimer(withTimeInterval: dauer, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.wortPlayer?.stop() }
        }
    }

    /// Wort an einer Textstelle (für die Wort-Lupe): (Teil, Wort) oder nil.
    func wort(seite: Int, block: Int, item: Int, zeichen: Int, alt: Bool) -> (Int, VorleseDaten.Wort)? {
        for (i, teil) in teile.enumerated() {
            for w in teil.daten.words {
                let s = teil.daten.segments[w.s]
                guard s.seite == seite, s.block == block, s.item == item else { continue }
                let von = alt ? (w.aa ?? w.a) : w.a
                let bis = alt ? (w.ae ?? w.e) : w.e
                if von <= zeichen && zeichen < bis { return (i, w) }
            }
        }
        return nil
    }

    private func tick() {
        guard let p = player, let d = daten, !d.words.isEmpty else { return }
        let ms = Int(p.currentTime * 1000)
        let gesamt = teile.reduce(0) { $0 + $1.daten.duration }
        let davor = teile.prefix(teilIndex).reduce(0) { $0 + $1.daten.duration }
        fortschritt = gesamt > 0 ? Double(davor + ms) / Double(gesamt) : 0
        var k = zuletzt
        if k > 0 && d.words[k].t > ms { k = 0 }
        while k + 1 < d.words.count && d.words[k + 1].t <= ms { k += 1 }
        zuletzt = k
        guard d.words[k].t <= ms else { markierung = nil; return }
        // Fenster: 1 bis 3 Wörter, zusammen etwa 0,6 s Sprechzeit, nie über Satzende (. ! ?) oder Absatz hinaus
        let ziel = 600.0 / Double(rate)
        var ende = k
        var summe = Double(d.words[k].d)
        while ende + 1 < d.words.count && ende - k < 2 && d.words[ende + 1].s == d.words[k].s
                && d.words[ende].p != true && summe < ziel {
            ende += 1
            summe += Double(d.words[ende].d)
        }
        let seg = d.segments[d.words[k].s]
        let a = d.words[k], e = d.words[ende]
        let neu = LeseMarkierung(seite: seg.seite, block: seg.block, item: seg.item,
                                 neu: a.a..<max(a.a, e.e), alt: (a.aa ?? a.a)..<max(a.aa ?? a.a, e.ae ?? e.e))
        if neu != markierung { markierung = neu }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.timer?.invalidate()
            self.markierung = nil
            if self.teilIndex + 1 < self.teile.count, self.ladeTeil(self.teilIndex + 1) {
                self.start()
            } else {
                self.laeuft = false
                self.fortschritt = 0
                self.zuletzt = 0
                self.ladeTeil(0)
            }
        }
    }
}
