import UIKit

/// Lädt content.json, Audio-Index und Bilder aus dem Bundle-Ordner `Content/` (Folder-Reference, Hierarchie bleibt).
final class ContentRepository: ObservableObject {
    let bibliothek: Bibliothek
    let audioIndex: AudioIndex
    let lernen: LernInhalte
    private let cache = NSCache<NSString, UIImage>()
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        var lib = Bibliothek(version: 0, buch: Buch(titel: "", untertitel: "", autoren: "", ortJahr: "", einband: "", titelblatt: ""),
                             vorsatz: [], kapitel: [], inhaltsverzeichnis: [], tafeln: [], menus: [], fibel: nil, ueber: [])
        if let url = bundle.url(forResource: "content", withExtension: "json", subdirectory: "Content"),
           let data = try? Data(contentsOf: url) {
            do { lib = try JSONDecoder().decode(Bibliothek.self, from: data) } catch { print("content.json: \(error)") }
        }
        bibliothek = lib
        var lern = LernInhalte()
        if let url = bundle.url(forResource: "lernen", withExtension: "json", subdirectory: "Content"),
           let data = try? Data(contentsOf: url) {
            do { lern = try JSONDecoder().decode(LernInhalte.self, from: data) }
            catch { print("lernen.json: \(error)") }
        }
        lernen = lern
        var idx = AudioIndex(kapitel: [:], tafeln: [:], menus: [:])
        if let url = bundle.url(forResource: "index", withExtension: "json", subdirectory: "Content/Audio"),
           let data = try? Data(contentsOf: url), let d = try? JSONDecoder().decode(AudioIndex.self, from: data) {
            idx = d
        }
        audioIndex = idx
        cache.countLimit = 24
    }

    var buch: Buch { bibliothek.buch }
    var kapitel: [Kapitel] { bibliothek.kapitel }
    var alleTafeln: [Tafel] { bibliothek.tafeln.flatMap(\.tafeln) }
    var alleKarten: [Menukarte] { bibliothek.menus.flatMap(\.karten) }
    var seitenGesamt: Int { kapitel.reduce(0) { $0 + $1.seiten.count } }

    func kapitel(_ slug: String) -> Kapitel? { kapitel.first { $0.slug == slug } }
    func tafel(_ nr: String) -> Tafel? { alleTafeln.first { $0.nr == nr } }

    func naechstes(nach slug: String) -> Kapitel? {
        guard let i = kapitel.firstIndex(where: { $0.slug == slug }), i + 1 < kapitel.count else { return nil }
        return kapitel[i + 1]
    }

    func vorheriges(vor slug: String) -> Kapitel? {
        guard let i = kapitel.firstIndex(where: { $0.slug == slug }), i > 0 else { return nil }
        return kapitel[i - 1]
    }

    // MARK: Bilder

    func bild(_ name: String, ordner: String = "Content/Images") -> UIImage? {
        let key = "\(ordner)/\(name)" as NSString
        if let img = cache.object(forKey: key) { return img }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "jpg" : (name as NSString).pathExtension
        guard let url = bundle.url(forResource: base, withExtension: ext, subdirectory: ordner),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }

    func original(_ name: String) -> UIImage? { bild(name, ordner: "Content/Originals") }
    func thumb(_ name: String) -> UIImage? { bild(name, ordner: "Content/Thumbs") }

    // MARK: Audio

    func audioURL(_ stem: String) -> URL? {
        bundle.url(forResource: stem, withExtension: "m4a", subdirectory: "Content/Audio")
    }

    func vorleseDaten(_ stem: String) -> VorleseDaten? {
        guard let url = bundle.url(forResource: stem, withExtension: "json", subdirectory: "Content/Audio"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(VorleseDaten.self, from: data)
    }

    func audioTeile(_ kapitel: Kapitel) -> [AudioIndex.Teil] { audioIndex.kapitel[kapitel.slug] ?? [] }
}
