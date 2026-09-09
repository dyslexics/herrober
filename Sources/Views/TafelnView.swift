import SwiftUI

/// Übersicht der Bildtafeln (Gruppen, Thumbs) und der Menus.
struct TafelnView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    private let spalten = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(T("tafeln.sub")).font(Schrift.text).foregroundStyle(Theme.leise)
                ForEach(repo.bibliothek.tafeln) { g in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(g.titel).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
                        LazyVGrid(columns: spalten, spacing: 12) {
                            ForEach(g.tafeln) { t in
                                Button { nav.open(.tafel(t.nr)) } label: { TafelKachel(tafel: t) }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                StartKachel(titel: T("start.menus"), unter: T("menus.sub"), symbol: "list.bullet.rectangle") { nav.open(.menus) }
            }
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .navigationTitle(T("tafeln.title"))
    }
}

struct TafelKachel: View {
    let tafel: Tafel
    @EnvironmentObject private var repo: ContentRepository
    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let img = repo.thumb(tafel.bild) { Image(uiImage: img).resizable().scaledToFit() } else { Color.gray }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.linie))
            Text(T("tafel.n", tafel.nr)).font(Schrift.bold(13)).foregroundStyle(Theme.tinte)
            Text(tafel.titel).font(Schrift.klein).foregroundStyle(Theme.leise).lineLimit(2).multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Eine Tafel: zoombares Bild (Original/Bereinigt), Beschriftungen alt/neu + Französisch, Vorlesen, Ausschnitte.
struct TafelView: View {
    let tafel: Tafel
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var settings: Settings
    @StateObject private var vorleser = Vorleser()
    @State private var alt = true
    @State private var original = false
    @State private var detail: Detail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                bild
                Picker("", selection: $original) {
                    Text(T("tafel.clean")).tag(false)
                    Text(T("tafel.original")).tag(true)
                }
                .pickerStyle(.segmented)
                if !tafel.details.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Text(T("tafel.details")).font(Schrift.meta).foregroundStyle(Theme.leise)
                            ForEach(Array(tafel.details.enumerated()), id: \.offset) { _, d in
                                Button { detail = d } label: {
                                    if let img = repo.thumb(d.bild) { Image(uiImage: img).resizable().scaledToFit().frame(height: 60).clipShape(RoundedRectangle(cornerRadius: 6)) }
                                }
                            }
                        }
                    }
                }
                beschriftungen
                if let text = tafel.text, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(text.enumerated()), id: \.offset) { i, b in
                            BlockView(block: b, seite: 0, index: 1000 + i, alt: alt)
                        }
                    }
                }
            }
            .frame(maxWidth: Theme.leseBreite)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .environment(\.leseMarkierung, vorleser.markierung)
        .navigationTitle(T("tafel.n", tafel.nr) + " · " + T("tafel.page", tafel.seite))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { SchriftUmschalter(alt: $alt) } }
        .safeAreaInset(edge: .bottom) { if vorleser.bereit { VorleseZeile(vorleser: vorleser) } }
        .sheet(item: $detail) { d in DetailBild(detail: d) }
        .onAppear {
            alt = Launch.alt ?? settings.altSchrift
            if let stem = repo.audioIndex.tafeln[tafel.nr], let url = repo.audioURL(stem), let d = repo.vorleseDaten(stem) {
                vorleser.laden([VorleseTeil(url: url, daten: d)])
                if Launch.vorlesen { vorleser.start() }
            }
        }
        .onDisappear { vorleser.stop() }
        .tint(Theme.akzent)
    }

    private var bild: some View {
        Group {
            if let img = original ? repo.original(tafel.bild) : repo.bild(tafel.bild) {
                ZoomBild(image: img)
                    .frame(height: 460)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.linie))
                    .accessibilityLabel(T("tafel.n", tafel.nr) + ", " + tafel.titel)
            }
        }
    }

    private var beschriftungen: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("tafel.labels")).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(tafel.beschriftungen.enumerated()), id: \.offset) { i, b in
                    VStack(alignment: .leading, spacing: 2) {
                        if let de = b.deNeu, !de.isEmpty {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                if let nr = b.nr { Text(nr + ".").font(Schrift.bold(15)).foregroundStyle(Theme.akzent).monospacedDigit() }
                                AbsatzText(text: b.text(alt: alt), antiqua: b.antiquaBereiche, alt: alt, groesse: CGFloat(settings.fontSize) * (b.gruppe == true ? 1.05 : 1),
                                           zeilenabstand: 2, fett: b.gruppe == true, markierung: bereich(i), zugaenglich: de)
                            }
                        }
                        if let fr = b.fr, !fr.isEmpty {
                            Text(fr).font(Schrift.regular(CGFloat(settings.fontSize) * 0.85)).foregroundStyle(Theme.leise).padding(.leading, b.nr == nil ? 0 : 26)
                        }
                    }
                    .padding(.top, b.gruppe == true ? 6 : 0)
                }
            }
            .padding(14)
            .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.linie, lineWidth: 1))
        }
    }

    private func bereich(_ i: Int) -> Range<Int>? {
        guard let m = vorleser.markierung, m.block == i else { return nil }
        return m.bereich(alt: alt)
    }
}

extension Detail: Identifiable { var id: String { bild } }

struct DetailBild: View {
    let detail: Detail
    @EnvironmentObject private var repo: ContentRepository
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group { if let img = repo.bild(detail.bild) { ZoomBild(image: img) } }
                .background(Theme.bg)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("common.done")) { dismiss() } } }
        }
    }
}

/// Zoombares Bild (UIScrollView): Doppeltipp zoomt, Pinch bis 5×. Layout passiert in layoutSubviews,
/// weil die Bounds beim ersten updateUIView noch 0 sind.
final class ZoomScrollView: UIScrollView {
    let imageView = UIImageView()
    override func layoutSubviews() {
        super.layoutSubviews()
        if zoomScale == 1 {
            imageView.frame = bounds
            contentSize = bounds.size
        }
    }
}

struct ZoomBild: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomScrollView {
        let sv = ZoomScrollView()
        sv.delegate = context.coordinator
        sv.minimumZoomScale = 1; sv.maximumZoomScale = 5
        sv.showsVerticalScrollIndicator = false; sv.showsHorizontalScrollIndicator = false
        sv.bouncesZoom = true
        sv.imageView.image = image
        sv.imageView.contentMode = .scaleAspectFit
        sv.imageView.isUserInteractionEnabled = true
        sv.addSubview(sv.imageView)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doppeltipp(_:)))
        tap.numberOfTapsRequired = 2
        sv.addGestureRecognizer(tap)
        return sv
    }

    func updateUIView(_ sv: ZoomScrollView, context: Context) {
        if sv.imageView.image !== image {
            sv.setZoomScale(1, animated: false)
            sv.imageView.image = image
            sv.setNeedsLayout()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { (scrollView as? ZoomScrollView)?.imageView }
        @objc func doppeltipp(_ g: UITapGestureRecognizer) {
            guard let sv = g.view as? ZoomScrollView else { return }
            if sv.zoomScale > 1.5 { sv.setZoomScale(1, animated: true) } else {
                let p = g.location(in: sv.imageView)
                let w = sv.bounds.width / 3, h = sv.bounds.height / 3
                sv.zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
            }
        }
    }
}

/// Menus und Tischkarten: Liste, dann Karte mit Bild + Zeilen + Vorlesen.
struct MenusView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var nav: Navigator
    private let spalten = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(T("menus.sub")).font(Schrift.text).foregroundStyle(Theme.leise)
                ForEach(repo.bibliothek.menus) { g in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(g.titel).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
                        LazyVGrid(columns: spalten, spacing: 12) {
                            ForEach(g.karten) { k in
                                Button { nav.open(.menu(k.bild)) } label: {
                                    VStack(spacing: 6) {
                                        Group { if let img = repo.thumb(k.bild) { Image(uiImage: img).resizable().scaledToFit() } else { Color.gray } }
                                            .frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.linie))
                                        Text(k.titel).font(Schrift.klein).foregroundStyle(Theme.tinte).lineLimit(2).multilineTextAlignment(.center)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .navigationTitle(T("menus.title"))
    }
}

struct MenuView: View {
    let karte: Menukarte
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var settings: Settings
    @StateObject private var vorleser = Vorleser()
    @State private var alt = true
    @State private var original = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let img = original ? repo.original(karte.bild) : repo.bild(karte.bild) {
                    ZoomBild(image: img).frame(height: 460).clipShape(RoundedRectangle(cornerRadius: Theme.radius)).overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.linie))
                }
                Picker("", selection: $original) { Text(T("tafel.clean")).tag(false); Text(T("tafel.original")).tag(true) }.pickerStyle(.segmented)
                if let od = karte.ortDatum, !od.isEmpty { Text(od).font(Schrift.meta).foregroundStyle(Theme.leise) }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(karte.zeilen.enumerated()), id: \.offset) { i, z in
                        let fett = z.art == "titel" || z.art == "ueberschrift"
                        AbsatzText(text: z.text(alt: alt), antiqua: z.antiquaBereiche, alt: alt && karte.sprache == "de",
                                   groesse: CGFloat(settings.fontSize) * (fett ? 1.1 : 1), zeilenabstand: 3, fett: fett,
                                   markierung: bereich(i), zugaenglich: z.neu, zentriert: true)
                            .padding(.top, z.art == "ueberschrift" ? 10 : 0)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.linie, lineWidth: 1))
            }
            .frame(maxWidth: Theme.leseBreite)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .navigationTitle(karte.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if karte.sprache == "de" { ToolbarItem(placement: .principal) { SchriftUmschalter(alt: $alt) } } }
        .safeAreaInset(edge: .bottom) { if vorleser.bereit { VorleseZeile(vorleser: vorleser) } }
        .onAppear {
            alt = Launch.alt ?? settings.altSchrift
            if let stem = repo.audioIndex.menus[karte.bild], let url = repo.audioURL(stem), let d = repo.vorleseDaten(stem) {
                vorleser.laden([VorleseTeil(url: url, daten: d)])
                if Launch.vorlesen { vorleser.start() }
            }
        }
        .onDisappear { vorleser.stop() }
        .tint(Theme.akzent)
    }

    private func bereich(_ i: Int) -> Range<Int>? {
        guard let m = vorleser.markierung, m.block == i else { return nil }
        return m.bereich(alt: alt && karte.sprache == "de")
    }
}
