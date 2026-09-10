import SwiftUI

enum AppLang: String, CaseIterable, Identifiable {
    case system, de, en
    var id: String { rawValue }
}

/// Darstellung: folgt dem System oder fest hell/dunkel.
enum Darstellung: String, CaseIterable, Identifiable {
    case system, hell, dunkel
    var id: String { rawValue }
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .hell: return .light
        case .dunkel: return .dark
        }
    }
}

/// Zentrale Einstellungen – UserDefaults, kein Konto, keine Cloud.
final class Settings: ObservableObject {
    private let d: UserDefaults

    static let groessen: ClosedRange<Double> = 16...28
    static let zeilenFaktoren: [Double] = [1.3, 1.5, 1.8]
    static var standardGroesse: Double { UIDevice.current.userInterfaceIdiom == .pad ? 22 : 20 }

    @Published var lang: AppLang {
        didSet { d.set(lang.rawValue, forKey: "lang"); L10n.lang = resolved }
    }
    /// Lesetext in Punkt (iPhone 20, iPad 22). Dynamic Type wirkt zusätzlich.
    @Published var fontSize: Double {
        didSet { d.set(fontSize, forKey: "fontSize") }
    }
    /// Zeilenhöhe als Faktor der Schriftgröße (1,3 / 1,5 / 1,8).
    @Published var lineFactor: Double {
        didSet { d.set(lineFactor, forKey: "lineFactor") }
    }
    @Published var darstellung: Darstellung {
        didSet { d.set(darstellung.rawValue, forKey: "darstellung") }
    }
    /// Alte Schrift (Fraktur mit langem ſ) statt Antiqua. Standard: an – das ist das Buch von 1899.
    @Published var altSchrift: Bool {
        didSet { d.set(altSchrift, forKey: "altSchrift") }
    }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        lang = AppLang(rawValue: defaults.string(forKey: "lang") ?? "") ?? .system
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? Settings.standardGroesse
        lineFactor = defaults.object(forKey: "lineFactor") as? Double ?? 1.5
        darstellung = Darstellung(rawValue: defaults.string(forKey: "darstellung") ?? "") ?? .system
        altSchrift = defaults.object(forKey: "altSchrift") as? Bool ?? true
        L10n.lang = lang == .system ? L10n.systemLang : lang.rawValue
    }

    /// Effektive UI-Sprache: "de" oder "en".
    var resolved: String { lang == .system ? L10n.systemLang : lang.rawValue }

    /// Zusätzlicher Zeilenabstand in Punkt: Zielzeilenhöhe minus natürlicher Zeilenhöhe der Schrift (~1,25).
    var lineSpacing: CGFloat { max(0, CGFloat(fontSize * (lineFactor - 1.25))) }

    var lineFactorText: String { String(format: "%.1f", locale: Locale(identifier: L10n.lang), lineFactor) }
}

enum Links {
    static let privacy = URL(string: "https://appsthrum.com/herrober/privacy.html")!
    static let kontakt = URL(string: "mailto:marioengel@me.com")!
    static let impressum = URL(string: "https://www.legasthenieverband.org/")!
    static let drc = URL(string: "https://drcag.com/")!
    static let quellcode = URL(string: "https://github.com/dyslexics/herrober")!
}

/// Eigene Lokalisierung: folgt der App-Einstellung, nicht nur der Systemsprache. Der Buchtext bleibt deutsch.
enum L10n {
    static var lang: String = systemLang

    static var systemLang: String {
        let pref = Locale.preferredLanguages.first ?? "en"
        return pref.hasPrefix("de") ? "de" : "en"
    }

    static func t(_ key: String) -> String {
        if lang == "de", let s = de[key] { return s }
        return en[key] ?? de[key] ?? key
    }

    static let de: [String: String] = [
        "tab.buch": "Buch",
        "tab.tafeln": "Tafeln",
        "tab.fibel": "Fibel",
        "tab.mehr": "Mehr",
        "app.title": "Herr Ober!",
        "app.sub": "Servierkunde · Wien 1899",
        "start.continue": "Weiterlesen",
        "start.begin": "Hier beginnen",
        "start.page": "Seite %@",
        "start.chapters": "Kapitel",
        "start.read.count": "%d von %d Seiten gelesen",
        "start.toc": "Inhaltsverzeichnis",
        "start.toc.sub": "Alle Abschnitte mit den Seitenzahlen des Originals",
        "start.tafeln": "Bildtafeln",
        "start.menus": "Menus",
        "start.fibel": "Fraktur-Fibel",
        "start.fibel.sub": "Die alte Schrift lesen lernen",
        "start.about": "Über das Buch",
        "cover.enlarge": "Vergrößern",
        "cover.open": "Bucheinband vergrößern",
        "cover.zoom.hint": "Mit zwei Fingern oder einem Doppeltipp vergrößern.",
        "chapter.page": "Seite %@",
        "chapter.next": "Nächstes Kapitel",
        "chapter.prev": "Vorheriges Kapitel",
        "chapter.pages": "%d Seiten · %d Min.",
        "chapter.done": "Kapitel gelesen",
        "schrift.alt": "Alte Schrift",
        "schrift.neu": "Neue Schrift",
        "schrift.toggle": "Schrift umschalten",
        "read.aloud": "Vorlesen",
        "read.rate": "Tempo",
        "read.pause": "Pause",
        "read.play": "Abspielen",
        "read.stop": "Stopp",
        "read.part": "Teil %d von %d",
        "lupe.title": "Wort-Lupe",
        "lupe.play": "Anhören",
        "lupe.hint": "Tippe auf ein Wort im Text, um es in neuer Schrift zu sehen.",
        "tafeln.title": "Bildtafeln",
        "tafeln.sub": "54 Tafeln aus dem Buch: Geschirr, Gläser, Bestecke und Gedecke",
        "tafel.n": "Tafel %@",
        "tafel.page": "Seite %@",
        "tafel.original": "Original-Scan",
        "tafel.clean": "Bereinigt",
        "tafel.labels": "Beschriftungen",
        "tafel.details": "Ausschnitte",
        "menus.title": "Menus",
        "menus.sub": "Speisenfolgen und Tischkarten aus dem Anhang des Buches",
        "fibel.title": "Fraktur-Fibel",
        "fibel.alphabet": "Das Alphabet",
        "fibel.stolper": "Stolpersteine",
        "fibel.words": "Übungswörter",
        "fibel.words.sub": "Tippe auf ein Wort: es erscheint in neuer Schrift und wird gesprochen.",
        "fibel.quiz": "Erkennst du es?",
        "fibel.quiz.sub": "Welches Wort steht hier in Fraktur?",
        "fibel.quiz.start": "Übung starten",
        "fibel.quiz.next": "Nächstes Wort",
        "fibel.quiz.score": "%d von %d richtig",
        "fibel.quiz.right": "Richtig!",
        "fibel.quiz.wrong": "Nicht ganz – schau noch einmal hin.",
        "fibel.quiz.again": "Noch einmal",
        "settings.title": "Einstellungen",
        "settings.reading": "Lesen",
        "settings.schrift": "Schrift beim Öffnen",
        "settings.textsize": "Schriftgröße",
        "settings.pt": "%d pt",
        "settings.spacing": "Zeilenabstand",
        "settings.preview": "Tritt ein Gast in das Lokal, so haben ihn die anwesenden Kellner stehend zu begrüßen.",
        "settings.language": "Sprache der App",
        "settings.lang.system": "Wie das Gerät",
        "settings.appearance": "Darstellung",
        "settings.appearance.system": "System",
        "settings.appearance.light": "Hell",
        "settings.appearance.dark": "Dunkel",
        "settings.about": "Über das Buch und die App",
        "settings.idea": "Nach einer Idee von Rainer Ternik",
        "settings.reset": "Lese- und Lernstand zurücksetzen",
        "settings.reset.confirm": "Dein Lesestand, gemerkte Begriffe, Fragen und Übungen werden auf diesem Gerät zurückgesetzt.",
        "settings.reset.do": "Zurücksetzen",
        "common.cancel": "Abbrechen",
        "common.done": "Fertig",
        "common.close": "Schließen",
        "about.title": "Über das Buch",
        "about.privacy": "Datenschutz",
        "about.contact": "Kontakt",
        "about.source": "Quellcode",
        "about.version": "Version",
        "about.cover": "Einband",
        "about.titlepage": "Titelblatt",
        "about.local": "Die App ist kostenlos, ohne Werbung und ohne Datensammlung. Dein Lesefortschritt bleibt auf diesem Gerät.",
        "toc.title": "Inhaltsverzeichnis",
        "toc.page": "S. %@",
    ]

    static let en: [String: String] = [
        "tab.buch": "Book",
        "tab.tafeln": "Plates",
        "tab.fibel": "Primer",
        "tab.mehr": "More",
        "app.title": "Herr Ober!",
        "app.sub": "The Art of Serving · Vienna 1899",
        "start.continue": "Continue reading",
        "start.begin": "Start here",
        "start.page": "Page %@",
        "start.chapters": "Chapters",
        "start.read.count": "%d of %d pages read",
        "start.toc": "Table of contents",
        "start.toc.sub": "All sections with the original page numbers",
        "start.tafeln": "Plates",
        "start.menus": "Menus",
        "start.fibel": "Fraktur primer",
        "start.fibel.sub": "Learn to read the old blackletter script",
        "start.about": "About the book",
        "cover.enlarge": "Enlarge",
        "cover.open": "Enlarge book cover",
        "cover.zoom.hint": "Pinch or double-tap to zoom in.",
        "chapter.page": "Page %@",
        "chapter.next": "Next chapter",
        "chapter.prev": "Previous chapter",
        "chapter.pages": "%d pages · %d min",
        "chapter.done": "Chapter read",
        "schrift.alt": "Old script",
        "schrift.neu": "Modern script",
        "schrift.toggle": "Switch script",
        "read.aloud": "Read aloud",
        "read.rate": "Speed",
        "read.pause": "Pause",
        "read.play": "Play",
        "read.stop": "Stop",
        "read.part": "Part %d of %d",
        "lupe.title": "Word lens",
        "lupe.play": "Listen",
        "lupe.hint": "Tap a word in the text to see it in modern script.",
        "tafeln.title": "Plates",
        "tafeln.sub": "54 plates from the book: china, glassware, cutlery and table settings",
        "tafel.n": "Plate %@",
        "tafel.page": "Page %@",
        "tafel.original": "Original scan",
        "tafel.clean": "Restored",
        "tafel.labels": "Captions",
        "tafel.details": "Details",
        "menus.title": "Menus",
        "menus.sub": "Menus and table cards from the book's appendix",
        "fibel.title": "Fraktur primer",
        "fibel.alphabet": "The alphabet",
        "fibel.stolper": "Tricky letters",
        "fibel.words": "Practice words",
        "fibel.words.sub": "Tap a word: it appears in modern script and is spoken.",
        "fibel.quiz": "Can you read it?",
        "fibel.quiz.sub": "Which word is written here in Fraktur?",
        "fibel.quiz.start": "Start practice",
        "fibel.quiz.next": "Next word",
        "fibel.quiz.score": "%d of %d correct",
        "fibel.quiz.right": "Correct!",
        "fibel.quiz.wrong": "Not quite – look again.",
        "fibel.quiz.again": "Once more",
        "settings.title": "Settings",
        "settings.reading": "Reading",
        "settings.schrift": "Script when opening",
        "settings.textsize": "Text size",
        "settings.pt": "%d pt",
        "settings.spacing": "Line spacing",
        "settings.preview": "Tritt ein Gast in das Lokal, so haben ihn die anwesenden Kellner stehend zu begrüßen.",
        "settings.language": "App language",
        "settings.lang.system": "Same as device",
        "settings.appearance": "Appearance",
        "settings.appearance.system": "System",
        "settings.appearance.light": "Light",
        "settings.appearance.dark": "Dark",
        "settings.about": "About the book and the app",
        "settings.idea": "Based on an idea by Rainer Ternik",
        "settings.reset": "Reset reading and learning progress",
        "settings.reset.confirm": "Your reading progress, saved terms, questions and exercises will be reset on this device.",
        "settings.reset.do": "Reset",
        "common.cancel": "Cancel",
        "common.done": "Done",
        "common.close": "Close",
        "about.title": "About the book",
        "about.privacy": "Privacy",
        "about.contact": "Contact",
        "about.source": "Source code",
        "about.version": "Version",
        "about.cover": "Cover",
        "about.titlepage": "Title page",
        "about.local": "The app is free, has no ads and collects no data. Your reading progress stays on this device.",
        "toc.title": "Table of contents",
        "toc.page": "p. %@",
    ]
}

func T(_ key: String) -> String { L10n.t(key) }

func T(_ key: String, _ args: CVarArg...) -> String {
    String(format: L10n.t(key), locale: Locale(identifier: L10n.lang), arguments: args)
}
