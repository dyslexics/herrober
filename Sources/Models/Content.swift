import Foundation

/// Content/content.json (tools/build_content.py). Jeder Textblock trägt den Antiqua-Text `neu` und die
/// Fraktur-Ableitung `alt` (langes ſ, ſs, ꝛc.); `antiqua` sind Zeichenbereiche in `alt`, die in Antiqua bleiben (Fremdwörter).
struct Bibliothek: Codable {
    let version: Int
    let buch: Buch
    let vorsatz: [Seite]
    let kapitel: [Kapitel]
    let inhaltsverzeichnis: [Inhaltseintrag]
    let tafeln: [Tafelgruppe]
    let menus: [Menugruppe]
    let fibel: Fibel?
    let ueber: [Block]
}

struct Buch: Codable {
    let titel: String
    let untertitel: String
    let autoren: String
    let ortJahr: String
    let einband: String
    let titelblatt: String
    enum CodingKeys: String, CodingKey { case titel, untertitel, autoren, einband, titelblatt; case ortJahr = "ort_jahr" }
}

struct Kapitel: Codable, Identifiable, Hashable {
    let slug: String
    let nummer: String
    let titel: String
    let seiten: [Seite]
    let woerter: Int

    var id: String { slug }
    var name: String { nummer.isEmpty ? titel : "\(nummer) · \(titel)" }
    var ersteSeite: String { seiten.first?.nr ?? "" }
    var letzteSeite: String { seiten.last?.nr ?? "" }
    static func == (a: Kapitel, b: Kapitel) -> Bool { a.slug == b.slug }
    func hash(into h: inout Hasher) { h.combine(slug) }
}

struct Seite: Codable {
    let nr: String
    let titel: String
    let bild: String?
    let bloecke: [Block]
}

/// Textblock (absatz, randtitel, ueberschrift, fussnote, zitat), Liste oder Tabelle.
struct Block: Codable {
    let typ: String
    let neu: String?
    let alt: String?
    let antiqua: [[Int]]?
    let ebene: Int?
    let nummeriert: Bool?
    let items: [Block]?
    let zeilen: [[String]]?

    var istText: Bool { neu != nil }
    func text(alt altSchrift: Bool) -> String { altSchrift ? (alt ?? neu ?? "") : (neu ?? "") }
    var antiquaBereiche: [Range<Int>] { (antiqua ?? []).compactMap { $0.count == 2 && $0[0] < $0[1] ? $0[0]..<$0[1] : nil } }
}

struct Inhaltseintrag: Codable { let titel: String; let seite: String }

struct Tafelgruppe: Codable, Identifiable {
    let slug: String
    let titel: String
    let text: [Textseite]
    let tafeln: [Tafel]
    var id: String { slug }
}

struct Textseite: Codable { let seite: String; let titel: String; let bloecke: [Block] }

struct Tafel: Codable, Identifiable, Hashable {
    let nr: String
    let seite: String
    let bild: String
    let titel: String
    let beschriftungen: [Beschriftung]
    let details: [Detail]
    let text: [Block]?
    var id: String { nr }
    static func == (a: Tafel, b: Tafel) -> Bool { a.nr == b.nr }
    func hash(into h: inout Hasher) { h.combine(nr) }
}

struct Beschriftung: Codable, Identifiable {
    let deNeu: String?
    let deAlt: String?
    let antiqua: [[Int]]?
    let fr: String?
    let nr: String?
    let gruppe: Bool?
    var id: String { (nr ?? "") + (deNeu ?? "") + (fr ?? "") }
    enum CodingKeys: String, CodingKey { case antiqua, fr, nr, gruppe; case deNeu = "de_neu"; case deAlt = "de_alt" }
    func text(alt: Bool) -> String { alt ? (deAlt ?? deNeu ?? "") : (deNeu ?? "") }
    var antiquaBereiche: [Range<Int>] { (antiqua ?? []).compactMap { $0.count == 2 && $0[0] < $0[1] ? $0[0]..<$0[1] : nil } }
}

struct Detail: Codable { let bild: String; let crop: [Double] }

struct Menugruppe: Codable, Identifiable {
    let slug: String
    let titel: String
    let text: [Textseite]
    let karten: [Menukarte]
    var id: String { slug }
}

struct Menukarte: Codable, Identifiable, Hashable {
    let bild: String
    let titel: String
    let ortDatum: String?
    let sprache: String?
    let zeilen: [Menuzeile]
    var id: String { bild }
    enum CodingKeys: String, CodingKey { case bild, titel, sprache, zeilen; case ortDatum = "ort_datum" }
    static func == (a: Menukarte, b: Menukarte) -> Bool { a.bild == b.bild }
    func hash(into h: inout Hasher) { h.combine(bild) }
}

struct Menuzeile: Codable, Identifiable {
    let neu: String
    let alt: String
    let art: String
    let antiqua: [[Int]]?
    var id: String { neu + art }
    func text(alt altSchrift: Bool) -> String { altSchrift ? alt : neu }
    var antiquaBereiche: [Range<Int>] { (antiqua ?? []).compactMap { $0.count == 2 && $0[0] < $0[1] ? $0[0]..<$0[1] : nil } }
}

struct Fibel: Codable {
    let einleitung: String
    let alphabet: [Buchstabe]
    let stolpersteine: [Stolperstein]
    let uebungswoerter: [Uebungswort]
}

struct Buchstabe: Codable, Identifiable { let gross: String; let klein: String; let hinweis: String; var id: String { gross + klein } }
struct Stolperstein: Codable, Identifiable { let alt: String; let neu: String; let titel: String; let erklaerung: String; var id: String { titel } }
struct Uebungswort: Codable, Identifiable { let neu: String; let alt: String; let falsch: [String]; var id: String { neu } }

/// Content/Audio/index.json (tools/build_audio.py)
struct AudioIndex: Codable {
    struct Teil: Codable { let stem: String; let seiten: [String]; let duration: Int }
    let kapitel: [String: [Teil]]
    let tafeln: [String: String]
    let menus: [String: String]
}
