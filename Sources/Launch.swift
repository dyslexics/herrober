import Foundation

/// Startargumente für Screenshots, Demo-Zustände und Tests (nur DEBUG). simctl kann keine Taps – deshalb Navigation per Arg.
///   -tab N            Tab 0 Buch, 1 Tafeln, 2 Fibel, 3 Mehr
///   -kapitel SLUG     Kapitel öffnen (einleitung, capitel-01 … capitel-10, couvertpreise)
///   -seite NR         zu dieser gedruckten Seite scrollen
///   -alt | -neu       Schrift beim Start
///   -vorlesen         Vorlesen sofort starten (Screenshots der Wortmarkierung)
///   -tafel NR         Tafel öffnen
///   -menu BILD        Menükarte öffnen (Dateiname ohne .jpg)
///   -screen fibel|quiz|ueber|toc|settings
///   -lang de|en       UI-Sprache
///   -demoProgress     Beispiel-Lesestand
enum Launch {
    #if DEBUG
    private static let args = ProcessInfo.processInfo.arguments
    #else
    private static let args: [String] = []
    #endif

    static func hat(_ flag: String) -> Bool { args.contains(flag) }

    static func wert(_ schluessel: String) -> String? {
        guard let i = args.firstIndex(of: schluessel), i + 1 < args.count else { return nil }
        let v = args[i + 1]
        return v.hasPrefix("-") ? nil : v
    }

    static func zahl(_ schluessel: String) -> Int? { wert(schluessel).flatMap(Int.init) }

    static var tab: Int? { zahl("-tab") }
    static var lang: String? { wert("-lang") }
    static var kapitel: String? { wert("-kapitel") }
    static var seite: String? { wert("-seite") }
    static var alt: Bool? { hat("-alt") ? true : (hat("-neu") ? false : nil) }
    static var vorlesen: Bool { hat("-vorlesen") }
    static var tafel: String? { wert("-tafel") }
    static var menu: String? { wert("-menu") }
    static var screen: String? { wert("-screen") }
    static var demoProgress: Bool { hat("-demoProgress") }
}
