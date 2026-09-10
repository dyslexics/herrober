import AVFoundation
import SwiftUI

/// Importierte Aufnahmen mit Wortzeiten; ohne passende Aufnahme spricht die Systemstimme.
/// Ein Sprecher pro Lernziel verhindert gleichzeitig laufende Erklärungen.
final class LernStimme: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var aktiv: String?
    @Published private(set) var bereich: NSRange?
    @Published var langsam = true { didSet { aufnahme.langsam = langsam } }
    private let synth = AVSpeechSynthesizer()
    private let aufnahme = AufnahmePlayer()
    private var aktuell: AVSpeechUtterance?
    override init() { super.init(); synth.delegate = self }
    func lesen(_ text: String, id: String, sprache: String = "de-AT") {
        if aktiv == id { stop(); return }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        aktiv = id
        aufnahme.langsam = langsam
        if aufnahme.lesen(text, sprache: sprache, markierung: { [weak self] in self?.bereich = $0 },
                          fertig: { [weak self] in self?.aktiv = nil; self?.bereich = nil }) { return }
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: sprache) ?? AVSpeechSynthesisVoice(language: "de-DE")
        u.rate = langsam ? 0.40 : 0.50
        aktuell = u; aktiv = id
        synth.speak(u)
    }
    func stop() { aktuell = nil; aufnahme.stop(); synth.stopSpeaking(at: .immediate); aktiv = nil; bereich = nil }
    func markierung(_ text: String, id: String) -> Range<Int>? {
        guard aktiv == id, let bereich, let r = Range(bereich, in: text) else { return nil }
        return text.distance(from: text.startIndex, to: r.lowerBound)..<text.distance(from: text.startIndex, to: r.upperBound)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.aktuell === utterance else { return }
            self.bereich = characterRange
        }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.aktuell === utterance else { return }
            self.aktuell = nil; self.aktiv = nil; self.bereich = nil
        }
    }
}

/// Kleine Ergänzung zur bestehenden DE/EN-Oberfläche; die Lerninhalte sind wie das Buch deutsch.
func LT(_ de: String, _ en: String) -> String { L10n.lang == "en" ? en : de }
