import AVFoundation
import UIKit

@MainActor
final class Feedback {
    private var players: [String: AVAudioPlayer] = [:]

    func play(_ name: String, settings: PlayerSettings) {
        if settings.haptics {
            if name == "era" {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
            }
        }
        guard settings.sound else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            if players[name] == nil, let url = Bundle.main.url(forResource: name, withExtension: "wav") {
                players[name] = try AVAudioPlayer(contentsOf: url)
                players[name]?.volume = 0.26
                players[name]?.prepareToPlay()
            }
            players[name]?.currentTime = 0
            players[name]?.play()
        } catch { /* Audio is optional; the visible result remains authoritative. */ }
    }

    func invalid(settings: PlayerSettings) {
        if settings.haptics { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }
}
