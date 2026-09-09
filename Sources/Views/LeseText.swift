import SwiftUI
import UIKit

/// Eine Textzeile/ein Absatz als UITextView: Fraktur oder Antiqua, Antiqua-Bereiche innerhalb der Fraktur,
/// Textmarker für das vorgelesene Wort, Tipp auf ein Wort → Wort-Lupe. Höhe passt sich der Breite an.
struct AbsatzText: UIViewRepresentable {
    let text: String
    let antiqua: [Range<Int>]
    let alt: Bool
    let groesse: CGFloat
    let zeilenabstand: CGFloat
    var fett = false
    var farbe: UIColor = Theme.tinteUI
    var markierung: Range<Int>? = nil
    var zugaenglich: String? = nil
    var zentriert = false
    var beimTippen: ((Int) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.adjustsFontForContentSizeCategory = false
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.required, for: .vertical)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tippen(_:)))
        tv.addGestureRecognizer(tap)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.beimTippen = beimTippen
        tv.attributedText = attributiert()
        tv.isAccessibilityElement = true
        tv.accessibilityLabel = zugaenglich ?? text
        tv.accessibilityTraits = .staticText
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let breite = proposal.width ?? UIScreen.main.bounds.width - 2 * Theme.seite
        let s = uiView.sizeThatFits(CGSize(width: breite, height: .greatestFiniteMagnitude))
        return CGSize(width: breite, height: ceil(s.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var beimTippen: ((Int) -> Void)?
        @objc func tippen(_ g: UITapGestureRecognizer) {
            guard let tv = g.view as? UITextView, let beimTippen else { return }
            let p = g.location(in: tv)
            let idx = tv.layoutManager.characterIndex(for: p, in: tv.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            guard idx < tv.textStorage.length else { return }
            beimTippen(idx)
        }
    }

    private func attributiert() -> NSAttributedString {
        let dyn = UIFontMetrics(forTextStyle: .body).scaledValue(for: groesse)
        let basis = fett ? Schrift.uiFett(dyn, alt: alt) : Schrift.uiLese(dyn, alt: alt)
        let absatz = NSMutableParagraphStyle()
        absatz.lineSpacing = zeilenabstand
        absatz.alignment = zentriert ? .center : .natural
        let a = NSMutableAttributedString(string: text, attributes: [.font: basis, .foregroundColor: farbe, .paragraphStyle: absatz])
        let n = (text as NSString).length
        if alt {
            let antiquaFont = fett ? Schrift.uiFett(dyn * 0.92, alt: false) : Schrift.uiAntiqua(dyn * 0.92)
            for r in antiqua {
                let ns = nsRange(r, in: text)
                if ns.location + ns.length <= n { a.addAttribute(.font, value: antiquaFont, range: ns) }
            }
        }
        if let m = markierung, !m.isEmpty {
            let ns = nsRange(m, in: text)
            if ns.location + ns.length <= n { a.addAttribute(.backgroundColor, value: Theme.markierungUI, range: ns) }
        }
        return a
    }

    /// Zeichenbereich (Grapheme) → NSRange (UTF-16). Die Texte enthalten keine Zeichen außerhalb der BMP.
    private func nsRange(_ r: Range<Int>, in s: String) -> NSRange {
        let start = s.index(s.startIndex, offsetBy: min(r.lowerBound, s.count))
        let end = s.index(s.startIndex, offsetBy: min(r.upperBound, s.count))
        return NSRange(start..<end, in: s)
    }
}

/// Ein Block einer Buchseite (Absatz, Randtitel, Überschrift, Fußnote, Zitat, Liste, Tabelle).
struct BlockView: View {
    let block: Block
    let seite: Int
    let index: Int
    @EnvironmentObject private var settings: Settings
    @Environment(\.leseMarkierung) private var markierung: LeseMarkierung?
    var alt: Bool
    var beimTippen: ((Int, Int, Int) -> Void)? = nil   // (block, item, zeichen)

    private var groesse: CGFloat { CGFloat(settings.fontSize) }

    private func bereich(item: Int) -> Range<Int>? {
        guard let m = markierung, m.seite == seite, m.block == index, m.item == item else { return nil }
        return m.bereich(alt: alt)
    }

    var body: some View {
        switch block.typ {
        case "randtitel":
            AbsatzText(text: block.text(alt: alt), antiqua: block.antiquaBereiche, alt: alt, groesse: groesse * 0.85,
                       zeilenabstand: 2, fett: true, farbe: Theme.akzentUI, markierung: bereich(item: -1),
                       zugaenglich: block.neu, beimTippen: { beimTippen?(index, -1, $0) })
                .padding(.top, groesse * 0.5)
        case "ueberschrift":
            AbsatzText(text: block.text(alt: alt), antiqua: block.antiquaBereiche, alt: alt, groesse: groesse * ((block.ebene ?? 4) <= 2 ? 1.25 : 1.1),
                       zeilenabstand: 2, fett: true, markierung: bereich(item: -1), zugaenglich: block.neu,
                       zentriert: (block.ebene ?? 4) <= 4, beimTippen: { beimTippen?(index, -1, $0) })
                .padding(.vertical, groesse * 0.4)
                .accessibilityAddTraits(.isHeader)
        case "fussnote":
            AbsatzText(text: block.text(alt: alt), antiqua: block.antiquaBereiche, alt: alt, groesse: groesse * 0.82,
                       zeilenabstand: settings.lineSpacing * 0.6, farbe: UIColor(Theme.leise), markierung: bereich(item: -1),
                       zugaenglich: block.neu, beimTippen: { beimTippen?(index, -1, $0) })
        case "zitat":
            AbsatzText(text: block.text(alt: alt), antiqua: block.antiquaBereiche, alt: alt, groesse: groesse,
                       zeilenabstand: settings.lineSpacing, markierung: bereich(item: -1), zugaenglich: block.neu,
                       beimTippen: { beimTippen?(index, -1, $0) })
                .padding(.leading, 14)
                .overlay(alignment: .leading) { Rectangle().fill(Theme.gold).frame(width: 3) }
        case "liste":
            VStack(alignment: .leading, spacing: groesse * 0.35) {
                ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { k, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text((block.nummeriert ?? false) ? "\(k + 1)." : "•")
                            .font(Schrift.leseFett(groesse, alt: alt)).foregroundStyle(Theme.akzent).monospacedDigit()
                        AbsatzText(text: item.text(alt: alt), antiqua: item.antiquaBereiche, alt: alt, groesse: groesse,
                                   zeilenabstand: settings.lineSpacing, markierung: bereich(item: k), zugaenglich: item.neu,
                                   beimTippen: { beimTippen?(index, k, $0) })
                    }
                }
            }
            .padding(.leading, 4)
        case "tabelle":
            TabelleView(zeilen: block.zeilen ?? [], alt: alt, groesse: groesse)
        default:
            AbsatzText(text: block.text(alt: alt), antiqua: block.antiquaBereiche, alt: alt, groesse: groesse,
                       zeilenabstand: settings.lineSpacing, markierung: bereich(item: -1), zugaenglich: block.neu,
                       beimTippen: { beimTippen?(index, -1, $0) })
        }
    }
}

/// Einfache Tabelle (Inhaltsverzeichnis-Auszüge, Preislisten): Antiqua, damit Zahlen lesbar bleiben.
struct TabelleView: View {
    let zeilen: [[String]]
    let alt: Bool
    let groesse: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(Array(zeilen.enumerated()), id: \.offset) { i, zeile in
                    GridRow {
                        ForEach(Array(zeile.enumerated()), id: \.offset) { _, zelle in
                            Text(zelle).font(i == 0 ? Schrift.bold(groesse * 0.85) : Schrift.regular(groesse * 0.85))
                        }
                    }
                    if i == 0 { Divider().gridCellUnsizedAxes(.horizontal) }
                }
            }
            .padding(10)
            .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
