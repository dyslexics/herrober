import AVFoundation
import SwiftUI

/// Fraktur-Fibel: Alphabet, Stolpersteine, Übungswörter, Erkennungsübung.
struct FibelView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var nav: Navigator
    @State private var gewaehlt: Uebungswort?
    private let sprecher = Sprecher()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let f = repo.bibliothek.fibel {
                    Text(f.einleitung).font(Schrift.text).foregroundStyle(Theme.leise)
                    uebung
                    StartKachel(titel: LT("Weiter mit Wortgruppen & Sätzen", "Continue with phrases & sentences"), unter: LT("12 Beispiele aus dem Buch · lesen und anhören", "12 examples from the book · read and listen"), symbol: "text.alignleft") { nav.open(.lernen("leseuebungen", "gruppe")) }
                    alphabet(f)
                    stolpersteine(f)
                    woerter(f)
                }
            }
            .frame(maxWidth: Theme.leseBreite)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.seite)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .navigationTitle(T("fibel.title"))
        .sheet(item: $gewaehlt) { w in
            VStack(spacing: 22) {
                Text(w.alt).font(Schrift.fraktur(44)).foregroundStyle(Theme.tinte)
                Text(w.neu).font(Schrift.bold(40)).foregroundStyle(Theme.akzent)
                PrimaerKnopf(titel: T("lupe.play"), symbol: "speaker.wave.2.fill") { sprecher.sprich(w.neu) }.frame(maxWidth: 260)
            }
            .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
            .presentationDetents([.height(320)])
            .onAppear { sprecher.sprich(w.neu) }
        }
    }

    private var uebung: some View {
        Karte {
            VStack(alignment: .leading, spacing: 8) {
                Text(T("fibel.quiz")).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
                Text(T("fibel.quiz.sub")).font(Schrift.meta).foregroundStyle(Theme.leise)
                if progress.data.fibelBest > 0 {
                    Text(T("fibel.quiz.score", progress.data.fibelBest, repo.bibliothek.fibel?.uebungswoerter.count ?? 0)).font(Schrift.klein).foregroundStyle(Theme.akzent)
                }
                PrimaerKnopf(titel: T("fibel.quiz.start"), symbol: "eye") { nav.open(.fibelQuiz) }
            }
        }
    }

    private func alphabet(_ f: Fibel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(T("fibel.alphabet")).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 10) {
                ForEach(f.alphabet) { b in
                    BuchstabenKachel(b: b) { sprecher.sprich($0) }
                }
            }
            ForEach(f.alphabet.filter { !$0.hinweis.isEmpty }) { b in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(b.gross + b.klein).font(Schrift.fraktur(22)).foregroundStyle(Theme.tinte).frame(width: 44, alignment: .leading)
                    Text(b.hinweis).font(Schrift.meta).foregroundStyle(Theme.leise)
                }
            }
        }
    }

    private func stolpersteine(_ f: Fibel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(T("fibel.stolper")).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
            ForEach(f.stolpersteine) { s in
                Karte {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(s.alt).font(Schrift.fraktur(30)).foregroundStyle(Theme.tinte)
                            Text(s.neu).font(Schrift.bold(18)).foregroundStyle(Theme.akzent)
                        }
                        Text(s.titel).font(Schrift.zeile).foregroundStyle(Theme.tinte)
                        Text(s.erklaerung).font(Schrift.meta).foregroundStyle(Theme.leise)
                    }
                }
            }
        }
    }

    private func woerter(_ f: Fibel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(T("fibel.words")).font(Schrift.abschnitt).foregroundStyle(Theme.tinte)
            Text(T("fibel.words.sub")).font(Schrift.meta).foregroundStyle(Theme.leise)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(f.uebungswoerter) { w in
                    Button { gewaehlt = w } label: {
                        Text(w.alt).font(Schrift.fraktur(26)).foregroundStyle(Theme.tinte).minimumScaleFactor(0.6).lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.linie))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(w.neu)
                }
            }
        }
    }
}

/// Ein Buchstabe der Alphabet-Tafel: groß in Fraktur, darunter in Antiqua.
struct BuchstabenKachel: View {
    let b: Buchstabe
    let sprich: (String) -> Void

    private var fraktur: String { b.gross + b.klein }
    private var antiqua: String { b.gross + (b.klein == "ſ" ? "s" : b.klein) }
    private var gesprochen: String { b.klein == "ſ" ? "langes s" : (b.gross.isEmpty ? b.klein : b.gross) }
    private var label: String { fraktur + (b.hinweis.isEmpty ? "" : ". " + b.hinweis) }

    var body: some View {
        VStack(spacing: 2) {
            Text(fraktur).font(Schrift.fraktur(30)).foregroundStyle(Theme.tinte).minimumScaleFactor(0.6).lineLimit(1)
            Text(antiqua).font(Schrift.bold(14)).foregroundStyle(Theme.akzent)
        }
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.linie))
        .overlay(alignment: .topTrailing) { hinweisPunkt }
        .accessibilityLabel(label)
        .onTapGesture { sprich(gesprochen) }
    }

    @ViewBuilder private var hinweisPunkt: some View {
        if !b.hinweis.isEmpty {
            Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(Theme.gold).padding(4)
        }
    }
}

/// Erkennungsübung: Wort in Fraktur, drei Antworten in Antiqua.
struct FibelQuizView: View {
    @EnvironmentObject private var repo: ContentRepository
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var reihenfolge: [Uebungswort] = []
    @State private var index = 0
    @State private var optionen: [String] = []
    @State private var gewaehlt: String?
    @State private var richtig = 0
    private let sprecher = Sprecher()

    private var wort: Uebungswort? { reihenfolge.indices.contains(index) ? reihenfolge[index] : nil }

    var body: some View {
        VStack(spacing: 22) {
            if let w = wort {
                Text("\(index + 1) / \(reihenfolge.count)").font(Schrift.meta).foregroundStyle(Theme.leise)
                Text(w.alt).font(Schrift.fraktur(46)).foregroundStyle(Theme.tinte).minimumScaleFactor(0.5).lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Theme.flaeche, in: RoundedRectangle(cornerRadius: Theme.radius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.linie))
                    .accessibilityLabel(T("fibel.quiz.sub"))
                ForEach(optionen, id: \.self) { o in
                    Button { antwort(o, w) } label: {
                        HStack {
                            Text(o).font(Schrift.bold(22))
                            Spacer()
                            if gewaehlt != nil && o == w.neu { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.erfolg) }
                            if gewaehlt == o && o != w.neu { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.fehler) }
                        }
                        .foregroundStyle(Theme.tinte)
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: Theme.knopfHoehe)
                        .background(hintergrund(o, w), in: RoundedRectangle(cornerRadius: Theme.radius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.linie))
                    }
                    .buttonStyle(.plain)
                    .disabled(gewaehlt != nil)
                }
                if let g = gewaehlt {
                    Text(g == w.neu ? T("fibel.quiz.right") : T("fibel.quiz.wrong")).font(Schrift.zeile).foregroundStyle(g == w.neu ? Theme.erfolg : Theme.fehler)
                    PrimaerKnopf(titel: index + 1 < reihenfolge.count ? T("fibel.quiz.next") : T("common.done"), symbol: "chevron.right") { weiter() }
                }
                Spacer()
            } else {
                Spacer()
                Text(T("fibel.quiz.score", richtig, reihenfolge.count)).font(Schrift.titel).foregroundStyle(Theme.tinte)
                PrimaerKnopf(titel: T("fibel.quiz.again"), symbol: "arrow.counterclockwise") { start() }
                Spacer()
            }
        }
        .padding(Theme.seite)
        .frame(maxWidth: Theme.leseBreite)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .navigationTitle(T("fibel.quiz"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if reihenfolge.isEmpty { start() } }
    }

    private func hintergrund(_ o: String, _ w: Uebungswort) -> Color {
        guard let g = gewaehlt else { return Theme.flaeche }
        if o == w.neu { return Theme.erfolg.opacity(0.18) }
        if g == o { return Theme.fehler.opacity(0.18) }
        return Theme.flaeche
    }

    private func start() {
        let alle = repo.bibliothek.fibel?.uebungswoerter ?? []
        reihenfolge = Launch.hat("-noShuffle") ? alle : alle.shuffled()
        index = 0; richtig = 0; gewaehlt = nil
        optionenLaden()
    }

    private func optionenLaden() {
        guard let w = wort else { return }
        var o = [w.neu] + w.falsch
        if !Launch.hat("-noShuffle") { o.shuffle() }
        optionen = o
    }

    private func antwort(_ o: String, _ w: Uebungswort) {
        gewaehlt = o
        if o == w.neu { richtig += 1 }
        sprecher.sprich(w.neu)
    }

    private func weiter() {
        gewaehlt = nil
        index += 1
        if wort == nil { progress.fibel(score: richtig) } else { optionenLaden() }
    }
}

/// Einzelne Wörter/Buchstaben sprechen (Fibel): AVSpeechSynthesizer, beste installierte deutsche Stimme.
final class Sprecher {
    private let synth = AVSpeechSynthesizer()
    private static let stimme: AVSpeechSynthesisVoice? = {
        let de = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("de") }
        return de.first { $0.quality == .premium } ?? de.first { $0.quality == .enhanced } ?? AVSpeechSynthesisVoice(language: "de-AT") ?? AVSpeechSynthesisVoice(language: "de-DE")
    }()

    func sprich(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: text)
        u.voice = Sprecher.stimme
        u.rate = 0.42
        synth.speak(u)
    }
}
