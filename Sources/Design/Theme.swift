import SwiftUI
import UIKit

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// Ein Farbwert, der Hell- und Dunkelmodus selbst auflöst.
    static func adaptiv(hell: UInt32, dunkel: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(rgb: trait.userInterfaceStyle == .dark ? dunkel : hell)
        })
    }
}

/// Wiener Kaffeehaus 1899: Papier, Tinte, Blau, Gold. Farbe ist nie das einzige Signal.
enum Theme {
    static let bg       = Color.adaptiv(hell: 0xF6EEDC, dunkel: 0x141B26)
    static let flaeche  = Color.adaptiv(hell: 0xFDF9F0, dunkel: 0x1D2939)
    static let tinte    = Color.adaptiv(hell: 0x2B2118, dunkel: 0xEEE6D4)
    static let leise    = Color.adaptiv(hell: 0x6E5F4B, dunkel: 0xB5AA95)
    static let akzent   = Color.adaptiv(hell: 0x234F7D, dunkel: 0xA8CBF0)
    static let gold     = Color.adaptiv(hell: 0xB08D3C, dunkel: 0xE2C57A)
    static let weich    = Color.adaptiv(hell: 0xE9E0C8, dunkel: 0x2A394D)
    static let linie    = Color.adaptiv(hell: 0xD9CDB2, dunkel: 0x364960)
    static let fehler   = Color.adaptiv(hell: 0x9A3838, dunkel: 0xF4B2AE)
    static let erfolg   = Color.adaptiv(hell: 0x236344, dunkel: 0x98D7B2)
    /// Textmarker für das mitlaufende Wort beim Vorlesen
    static let markierung = Color.adaptiv(hell: 0xFFE500, dunkel: 0x8C7A1F)
    static let markierungUI = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x8C7A1F) : UIColor(rgb: 0xFFE500) }
    static let tinteUI = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0xEEE6D4) : UIColor(rgb: 0x2B2118) }
    static let akzentUI = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0xA8CBF0) : UIColor(rgb: 0x234F7D) }
    /// Text auf Akzent-Flächen (Primärbutton)
    static let aufAkzent = Color.adaptiv(hell: 0xFFFFFF, dunkel: 0x141B26)

    static let radius: CGFloat = 12
    static let seite: CGFloat = 24
    static let knopfHoehe: CGFloat = 52
    static let leseBreite: CGFloat = 720
    static let mindestTouch: CGFloat = 44
}

/// Schriften: UnifrakturMaguntia (Fraktur, OFL) für die alte Schrift, Atkinson Hyperlegible (OFL) für die neue.
/// Fraktur wirkt kleiner (niedrige x-Höhe) und bekommt den Faktor 1,12.
enum Schrift {
    static let frakturName = "UnifrakturMaguntia"
    static let frakturFettName = "UnifrakturCook-Bold"
    static let antiquaName = "AtkinsonHyperlegible-Regular"
    static let antiquaFettName = "AtkinsonHyperlegible-Bold"
    static let frakturFaktor: CGFloat = 1.12

    static func regular(_ size: CGFloat) -> Font { .custom(antiquaName, size: size) }
    static func bold(_ size: CGFloat) -> Font { .custom(antiquaFettName, size: size) }
    static func fraktur(_ size: CGFloat) -> Font { .custom(frakturName, size: size * frakturFaktor) }
    static func frakturFett(_ size: CGFloat) -> Font { .custom(frakturFettName, size: size * frakturFaktor) }

    /// Lesetext je nach Schriftmodus.
    static func lese(_ size: CGFloat, alt: Bool) -> Font { alt ? fraktur(size) : regular(size) }
    static func leseFett(_ size: CGFloat, alt: Bool) -> Font { alt ? frakturFett(size) : bold(size) }

    static func uiLese(_ size: CGFloat, alt: Bool) -> UIFont {
        (alt ? UIFont(name: frakturName, size: size * frakturFaktor) : UIFont(name: antiquaName, size: size)) ?? .systemFont(ofSize: size)
    }
    static func uiAntiqua(_ size: CGFloat) -> UIFont { UIFont(name: antiquaName, size: size) ?? .systemFont(ofSize: size) }
    static func uiFett(_ size: CGFloat, alt: Bool) -> UIFont {
        (alt ? UIFont(name: frakturFettName, size: size * frakturFaktor) : UIFont(name: antiquaFettName, size: size)) ?? .boldSystemFont(ofSize: size)
    }

    static let titel = bold(30)
    static let abschnitt = bold(22)
    static let zeile = bold(17)
    static let text = regular(17)
    static let knopf = bold(17)
    static let meta = regular(14)
    static let klein = regular(13)
    static let eyebrow = bold(15)
}

// MARK: - Bausteine

/// Eyebrow (Buchtitel in Akzent) + Seitentitel.
struct SeitenKopf: View {
    var eyebrow: String? = nil
    let titel: String
    var untertitel: String? = nil
    var fraktur = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow).font(Schrift.eyebrow).foregroundStyle(Theme.akzent)
            }
            Text(titel)
                .font(fraktur ? Schrift.fraktur(30) : Schrift.titel)
                .foregroundStyle(Theme.tinte)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let untertitel {
                Text(untertitel).font(Schrift.text).foregroundStyle(Theme.leise)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

/// Primärbutton: 52 pt hoch, Radius 12, Akzentfläche.
struct PrimaerKnopf: View {
    let titel: String
    var symbol: String? = nil
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol) }
                Text(titel)
            }
            .font(Schrift.knopf)
            .foregroundStyle(Theme.aufAkzent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: Theme.knopfHoehe)
            .background(Theme.akzent, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Karte auf Papier.
struct Karte<Inhalt: View>: View {
    @ViewBuilder let inhalt: () -> Inhalt
    var body: some View {
        inhalt()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.linie, lineWidth: 1))
    }
}

/// Umschalter alte/neue Schrift – groß, mit Schriftprobe als Symbol.
struct SchriftUmschalter: View {
    @Binding var alt: Bool
    var body: some View {
        Picker(T("schrift.toggle"), selection: $alt) {
            Text("Alt").font(Schrift.fraktur(15)).tag(true).accessibilityLabel(T("schrift.alt"))
            Text("Neu").font(Schrift.bold(14)).tag(false).accessibilityLabel(T("schrift.neu"))
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
    }
}
