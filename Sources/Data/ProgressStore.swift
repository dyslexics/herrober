import Foundation

struct ProgressData: Codable {
    /// Gelesene Seiten als "slug/seitennummer"
    var seiten: Set<String> = []
    /// Vollständig gelesene Kapitel
    var kapitel: Set<String> = []
    var zuletztKapitel: String?
    var zuletztSeite: String?
    var fibelBest: Int = 0
}

/// Lesestand – nur lokal (UserDefaults), kein Konto.
final class ProgressStore: ObservableObject {
    @Published private(set) var data = ProgressData()
    @Published private(set) var lern = Lernstand()
    private let defaults: UserDefaults
    private let key = "progress.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.data(forKey: "lernen.v1"), let d = try? JSONDecoder().decode(Lernstand.self, from: raw) { lern = d }
        if let raw = defaults.data(forKey: key), let d = try? JSONDecoder().decode(ProgressData.self, from: raw) {
            data = d
        }
    }

    func istGelesen(_ kapitel: Kapitel) -> Bool { data.kapitel.contains(kapitel.slug) }
    func istGelesen(_ kapitel: Kapitel, seite: String) -> Bool { data.seiten.contains("\(kapitel.slug)/\(seite)") }
    func gelesen(in kapitel: Kapitel) -> Int { kapitel.seiten.filter { data.seiten.contains("\(kapitel.slug)/\($0.nr)") }.count }
    var seitenGelesen: Int { data.seiten.count }

    /// Aktuelle Position merken (beim Blättern).
    func position(_ kapitel: Kapitel, seite: String) {
        let id = "\(kapitel.slug)/\(seite)"
        var geaendert = false
        if !data.seiten.contains(id) { data.seiten.insert(id); geaendert = true }
        if data.zuletztKapitel != kapitel.slug || data.zuletztSeite != seite {
            data.zuletztKapitel = kapitel.slug; data.zuletztSeite = seite; geaendert = true
        }
        if geaendert { save() }
    }

    func kapitelGelesen(_ kapitel: Kapitel) {
        guard !data.kapitel.contains(kapitel.slug) else { return }
        data.kapitel.insert(kapitel.slug)
        save()
    }

    func fibel(score: Int) {
        guard score > data.fibelBest else { return }
        data.fibelBest = score
        save()
    }

    func reset() {
        data = ProgressData()
        defaults.removeObject(forKey: key)
        lern = Lernstand()
        defaults.removeObject(forKey: "lernen.v1")
    }

    func begriffMerken(_ id: String) {
        if lern.gemerkt.contains(id) { lern.gemerkt.remove(id) } else { lern.gemerkt.insert(id) }
        saveLernen()
    }
    func frage(_ id: String, richtig: Bool) {
        lern.beantwortet.insert(id)
        if richtig { lern.wiederholen.remove(id) } else { lern.wiederholen.insert(id) }
        saveLernen()
    }
    func schritt(_ id: String, tour: String, fertig: Bool) {
        let key = "\(tour)/\(id)"
        if fertig { lern.tourSchritte.insert(key) } else { lern.tourSchritte.remove(key) }
        saveLernen()
    }
    func uebung(_ id: String) { lern.uebungen.insert(id); saveLernen() }
    private func saveLernen() {
        if let raw = try? JSONEncoder().encode(lern) { defaults.set(raw, forKey: "lernen.v1") }
    }

    /// „Weiterlesen": zuletzt geöffnetes Kapitel + Seite, sonst das erste Kapitel.
    func weiterlesen(_ repo: ContentRepository) -> (Kapitel, String?)? {
        if let slug = data.zuletztKapitel, let k = repo.kapitel(slug) { return (k, data.zuletztSeite) }
        guard let erstes = repo.kapitel.first else { return nil }
        return (erstes, nil)
    }

    var hatBegonnen: Bool { data.zuletztKapitel != nil }

    /// Demo-Stand für Store-Screenshots (Launch-Arg -demoProgress). Nicht persistiert.
    func loadDemo(repo: ContentRepository) {
        var d = ProgressData()
        for k in repo.kapitel.prefix(3) {
            d.kapitel.insert(k.slug)
            for s in k.seiten { d.seiten.insert("\(k.slug)/\(s.nr)") }
        }
        if repo.kapitel.count > 3 {
            let k = repo.kapitel[3]
            for s in k.seiten.prefix(2) { d.seiten.insert("\(k.slug)/\(s.nr)") }
            d.zuletztKapitel = k.slug; d.zuletztSeite = k.seiten.dropFirst().first?.nr
        }
        d.fibelBest = 7
        data = d
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) { defaults.set(raw, forKey: key) }
    }
}
