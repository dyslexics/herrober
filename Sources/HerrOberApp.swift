import SwiftUI

@main
struct HerrOberApp: App {
    @StateObject private var repo: ContentRepository
    @StateObject private var progress: ProgressStore
    @StateObject private var settings: Settings
    @StateObject private var nav = Navigator()

    init() {
        let r = ContentRepository()
        let p = ProgressStore()
        if Launch.hat("-resetProgress") { p.reset() } // DEBUG-Argument, in Release wirkungslos.
        if Launch.demoProgress { p.loadDemo(repo: r) }
        let s = Settings()
        if let l = Launch.lang, let al = AppLang(rawValue: l) { s.lang = al }
        if let a = Launch.alt { s.altSchrift = a }
        if let d = Launch.darstellung { s.darstellung = d }
        _repo = StateObject(wrappedValue: r)
        _progress = StateObject(wrappedValue: p)
        _settings = StateObject(wrappedValue: s)
        HerrOberApp.tabLeiste()
    }

    /// Tab-Leiste in Papier mit Blau für den aktiven Tab.
    private static func tabLeiste() {
        let a = UITabBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Theme.flaeche)
        a.shadowColor = UIColor(Theme.linie)
        let leise = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0xB5AA95) : UIColor(rgb: 0x6E5F4B) }
        for item in [a.stackedLayoutAppearance, a.inlineLayoutAppearance, a.compactInlineLayoutAppearance] {
            item.normal.iconColor = leise
            item.normal.titleTextAttributes = [.foregroundColor: leise]
            item.selected.iconColor = Theme.akzentUI
            item.selected.titleTextAttributes = [.foregroundColor: Theme.akzentUI]
        }
        UITabBar.appearance().standardAppearance = a
        UITabBar.appearance().scrollEdgeAppearance = a
        let n = UINavigationBarAppearance()
        n.configureWithTransparentBackground()
        n.largeTitleTextAttributes = [.font: Schrift.uiFett(34, alt: false), .foregroundColor: Theme.tinteUI]
        n.titleTextAttributes = [.font: Schrift.uiFett(17, alt: false), .foregroundColor: Theme.tinteUI]
        UINavigationBar.appearance().standardAppearance = n
        UINavigationBar.appearance().scrollEdgeAppearance = n
        UINavigationBar.appearance().compactAppearance = n
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(repo)
                .environmentObject(progress)
                .environmentObject(settings)
                .environmentObject(nav)
                .environment(\.locale, Locale(identifier: settings.resolved))
                .preferredColorScheme(settings.darstellung.scheme)
        }
    }
}

/// Ziele der Navigation; jeder Tab hat seinen eigenen Pfad.
enum Route: Hashable {
    case kapitel(String, String?)   // slug, Startseite
    case tafel(String)
    case menus
    case menu(String)
    case fibelQuiz
    case toc
    case ueber
    case lernen(String, String)    // Art, stabile Inhalts-ID
}

final class Navigator: ObservableObject {
    @Published var tab = 0
    @Published var pfade: [NavigationPath] = [NavigationPath(), NavigationPath(), NavigationPath(), NavigationPath()]

    func open(_ r: Route) { pfade[tab].append(r) }

    /// Kapitelwechsel über die Fußknöpfe: aktuelles Kapitel durch das nächste ersetzen.
    func ersetzeKapitel(_ k: Kapitel) {
        if !pfade[tab].isEmpty { pfade[tab].removeLast() }
        pfade[tab].append(Route.kapitel(k.slug, nil))
    }

    func pfad(_ i: Int) -> Binding<NavigationPath> {
        Binding(get: { self.pfade[i] }, set: { self.pfade[i] = $0 })
    }
}

struct RootView: View {
    @EnvironmentObject private var settings: Settings
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    @State private var launched = false

    var body: some View {
        TabView(selection: $nav.tab) {
            NavigationStack(path: nav.pfad(0)) { StartView().routen() }
                .tabItem { Label(T("tab.buch"), systemImage: "book") }.tag(0)
            NavigationStack(path: nav.pfad(1)) { TafelnView().routen() }
                .tabItem { Label(T("tab.tafeln"), systemImage: "fork.knife") }.tag(1)
            NavigationStack(path: nav.pfad(2)) { FibelView().routen() }
                .tabItem { Label(T("tab.fibel"), systemImage: "textformat.abc") }.tag(2)
            NavigationStack(path: nav.pfad(3)) { EinstellungenView().routen() }
                .tabItem { Label(T("tab.mehr"), systemImage: "gearshape") }.tag(3)
        }
        .tint(Theme.akzent)
        .id(settings.resolved)
        .onAppear {
            guard !launched else { return }
            launched = true
            applyLaunch()
        }
    }

    /// Screenshot-/Demo-Navigation per Launch-Arg.
    private func applyLaunch() {
        if let t = Launch.tab { nav.tab = max(0, min(3, t)) }
        if let slug = Launch.kapitel, repo.kapitel(slug) != nil {
            nav.tab = 0; nav.open(.kapitel(slug, Launch.seite)); return
        }
        if let nr = Launch.tafel, repo.tafel(nr) != nil { nav.tab = 1; nav.open(.tafel(nr)); return }
        if let bild = Launch.menu { nav.tab = 1; nav.open(.menus); nav.open(.menu(bild + ".jpg")); return }
        switch Launch.screen {
        case "lernen": nav.tab = 0; nav.open(.lernen("hub", ""))
        case "glossar": nav.tab = 0; nav.open(.lernen("glossar", ""))
        case "lernfragen": nav.tab = 0; nav.open(.lernen("fragen", "capitel-02"))
        case "bildaufgabe": nav.tab = 0; nav.open(.lernen("bild", "gedeck"))
        case "leseuebungen": nav.tab = 2; nav.open(.lernen("leseuebungen", "satz"))
        case "fibel": nav.tab = 2
        case "quiz": nav.tab = 2; nav.open(.fibelQuiz)
        case "ueber": nav.tab = 3; nav.open(.ueber)
        case "toc": nav.tab = 0; nav.open(.toc)
        case "settings": nav.tab = 3
        default: break
        }
    }
}

extension View {
    /// Navigationsziele aller Tabs.
    func routen() -> some View {
        navigationDestination(for: Route.self) { r in
            RouteView(route: r)
        }
    }
}

struct RouteView: View {
    let route: Route
    @EnvironmentObject private var repo: ContentRepository
    var body: some View {
        switch route {
        case .kapitel(let slug, let seite):
            if let k = repo.kapitel(slug) { KapitelView(kapitel: k, startSeite: seite) } else { Text(slug) }
        case .tafel(let nr):
            if let t = repo.tafel(nr) { TafelView(tafel: t) } else { Text(nr) }
        case .menus: MenusView()
        case .menu(let bild):
            if let k = repo.alleKarten.first(where: { $0.bild == bild }) { MenuView(karte: k) } else { Text(bild) }
        case .fibelQuiz: FibelQuizView()
        case .toc: InhaltsverzeichnisView()
        case .ueber: UeberView()
        case .lernen(let art, let id): LernRouteView(art: art, id: id)
        }
    }
}
