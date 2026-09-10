import AVFoundation
import CryptoKit
import Foundation

/// Vertrag für tools/narration.py: exakte Text-/Sprachbindung, vorhandene Wortzeiten.
struct AufnahmeEintrag: Codable, Identifiable {
    let stem: String
    let segment: Int
    let text: String
    let language: String
    let category: String
    let supplement: Bool
    var id: String { AufnahmenKatalog.schluessel(text, sprache: language) }
}

final class AufnahmenKatalog {
    struct Index: Codable { let schema_version: Int; let entries: [String: AufnahmeEintrag] }
    static let shared = AufnahmenKatalog()
    private let directory: URL?
    private(set) var eintraege: [String: AufnahmeEintrag] = [:]

    init(directory: URL? = Bundle.main.resourceURL?.appendingPathComponent("Content/Audio")) {
        self.directory = directory
        guard let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("narration-index.json")),
              let index = try? JSONDecoder().decode(Index.self, from: data), index.schema_version == 1 else { return }
        eintraege = index.entries.filter { key, entry in
            key == Self.schluessel(entry.text, sprache: entry.language) && Self.sichererStem(entry.stem)
        }
    }

    static func schluessel(_ text: String, sprache: String) -> String {
        SHA256.hash(data: Data((sprache + "\n" + text).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func sichererStem(_ stem: String) -> Bool {
        !stem.isEmpty && !stem.contains("/") && !stem.contains("\\") && stem != "." && stem != ".."
    }

    /// Unicode-Skalarpositionen aus Python in die von UIKit erwarteten UTF-16-Bereiche umsetzen.
    static func bereich(_ text: String, von: Int, bis: Int) -> NSRange? {
        let scalars = text.unicodeScalars
        guard von >= 0, von < bis, bis <= scalars.count else { return nil }
        let a = scalars.index(scalars.startIndex, offsetBy: von)
        let e = scalars.index(scalars.startIndex, offsetBy: bis)
        return NSRange(a..<e, in: text)
    }

    func aufnahme(_ text: String, sprache: String) -> (URL, VorleseDaten, [VorleseDaten.Wort])? {
        guard let directory, let entry = eintraege[Self.schluessel(text, sprache: sprache)],
              entry.text == text, entry.language == sprache,
              let data = try? Data(contentsOf: directory.appendingPathComponent(entry.stem + ".json")),
              let meta = try? JSONDecoder().decode(VorleseDaten.self, from: data),
              meta.segments.indices.contains(entry.segment), meta.segments[entry.segment].text == text else { return nil }
        let words = meta.words.filter { $0.s == entry.segment }
        guard !words.isEmpty else { return nil }
        var ende = 0
        for word in words {
            guard Self.bereich(text, von: word.a, bis: word.e) != nil,
                  word.t >= ende, word.d > 0, word.t <= meta.duration, word.d <= meta.duration - word.t else { return nil }
            ende = word.t + word.d
        }
        let url = directory.appendingPathComponent(entry.stem + ".m4a")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return (url, meta, words)
    }
}

/// Spielt auch einen einzelnen Absatz aus einer längeren Kapitelaufnahme.
final class AufnahmePlayer: NSObject, AVAudioPlayerDelegate {
    private let katalog: AufnahmenKatalog
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var finish: (() -> Void)?
    var langsam = true { didSet { player?.rate = langsam ? 0.8 : 1.0 } }

    init(katalog: AufnahmenKatalog = .shared) { self.katalog = katalog; super.init() }

    @discardableResult
    func lesen(_ text: String, sprache: String, markierung: @escaping (NSRange?) -> Void,
               fertig: @escaping () -> Void) -> Bool {
        stop()
        guard let (url, meta, words) = katalog.aufnahme(text, sprache: sprache),
              let first = words.first, let last = words.last,
              let p = try? AVAudioPlayer(contentsOf: url) else { return false }
        let nachfolger = meta.words.first { $0.t > last.t && $0.s != last.s }?.t ?? meta.duration
        let ende = min(nachfolger, min(meta.duration, last.t + last.d + 120))
        p.delegate = self; p.enableRate = true; p.rate = langsam ? 0.8 : 1.0
        p.currentTime = max(0, Double(first.t) / 1000 - 0.02)
        guard p.play() else { return false }
        player = p; finish = fertig
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self, weak p] _ in
            guard let self, let p, self.player === p else { return }
            let ms = Int(p.currentTime * 1000)
            if ms >= ende { self.abgeschlossen(); return }
            let word = words.last { $0.t <= ms && ms < $0.t + $0.d }
            markierung(word.flatMap { AufnahmenKatalog.bereich(text, von: $0.a, bis: $0.e) })
        }
        return true
    }

    func stop() { timer?.invalidate(); timer = nil; player?.stop(); player = nil; finish = nil }
    private func abgeschlossen() { let done = finish; stop(); done?() }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }
        abgeschlossen()
    }
    deinit { timer?.invalidate(); player?.stop() }
}
