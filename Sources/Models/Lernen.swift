import Foundation

/// Heutige Redaktion, getrennt von der Buchtranskription und deren Audio-Zeitmarken.
struct LernInhalte: Codable {
    var version = 0
    var begriffe: [LernBegriff] = []
    var fragen: [LernFrage] = []
    var touren: [LernTour] = []
    var kontexte: [LernKontext] = []
    var leseuebungen: [LeseUebung] = []
    var bildaufgaben: [BildAufgabe] = []
    var menufuehrer: [MenuFuehrer] = []

    func begriff(_ id: String) -> LernBegriff? { begriffe.first { $0.id == id } }
    static func normal(_ text: String) -> String {
        text.replacingOccurrences(of: "ſ", with: "s").replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "œ", with: "oe")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de"))
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }
    /// Ein mehrteiliges Fremdwort braucht zusätzlich den passenden Satzkontext.
    func begriff(wort: String, kontext: String) -> LernBegriff? {
        let w = Self.normal(wort), k = Self.normal(kontext)
        guard !w.isEmpty else { return nil }
        return begriffe.first { b in b.formen.contains { f in
            let n = Self.normal(f)
            if n == w { return true }
            let teile = n.split { $0.isWhitespace || $0 == "-" }.map(String.init)
            return teile.count > 1 && teile.contains(w) && k.contains(n)
        } }
    }
}

struct LernQuelle: Codable, Hashable {
    let art: String
    let id: String
    let seite: String?
    let titel: String
    let zitat: String?
    var ziel: LernZiel { LernZiel(art: art, id: id, seite: seite) }
}
struct LernZiel: Codable, Hashable {
    let art: String
    let id: String
    var seite: String? = nil
    var route: Route {
        switch art {
        case "kapitel": return .kapitel(id, seite)
        case "tafel": return .tafel(id)
        case "menu": return .menu(id)
        case "fibelQuiz": return .fibelQuiz
        default: return .lernen(art, id)
        }
    }
}
struct LernBegriff: Codable, Identifiable {
    let id, titel: String
    let formen: [String]
    let text, anwendung: String
    let quelle: LernQuelle
}
struct LernFrage: Codable, Identifiable {
    let id, kapitel, frage: String
    let antworten: [String]
    let richtig: Int
    let erklaerung: String
    let quelle: LernQuelle
}
struct LernTour: Codable, Identifiable {
    let id, titel, dauer, text: String
    let schritte: [LernSchritt]
}
struct LernSchritt: Codable, Identifiable {
    let id, titel, text: String
    let ziel: LernZiel
}
struct LernKontext: Codable, Identifiable {
    let id, titel, text: String
    let quelle: LernQuelle
}
struct LeseUebung: Codable, Identifiable {
    let id, stufe, neu, alt: String
    let antiqua: [[Int]]
    let map: [Int]
    let quelle: LernQuelle
}
struct BildAufgabe: Codable, Identifiable {
    let id, titel, text: String
    let quelle: LernQuelle
    let bild, art: String
    let richtig: Int
    let optionen: [BildOption]
    let erklaerung: String
}
struct BildOption: Codable { let titel, beschreibung: String; let crop: [Double] }
struct MenuFuehrer: Codable, Identifiable {
    let id, menu, titel, text: String
    let quelle: LernQuelle
    let abschnitte: [MenuErklaerung]
    let links: [LernLink]
}
struct MenuErklaerung: Codable, Identifiable { let id, titel, zitat, text, sprache: String }
struct LernLink: Codable { let titel, url: String }

/// Separater Schlüssel: das Schema des vorhandenen Lesestands bleibt kompatibel.
struct Lernstand: Codable {
    var gemerkt: Set<String> = []
    var wiederholen: Set<String> = []
    var beantwortet: Set<String> = []
    var tourSchritte: Set<String> = []
    var uebungen: Set<String> = []
}
