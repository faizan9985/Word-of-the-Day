// Target membership: WordOfTheDay app only

import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechService: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var playbackTask: Task<Void, Never>?

    deinit {
        playbackTask?.cancel()
    }

    func pronounce(audioURL: URL?) {
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer?.stop()
        audioPlayer = nil

        guard let audioURL else {
            debugLog("Pronunciation audio URL found: false")
            return
        }
        debugLog("Pronunciation audio URL found: true")

        playbackTask = Task { [weak self] in
            guard let self else { return }

            do {
                let (data, response) = try await URLSession.shared.data(from: audioURL)
                try Task.checkCancellation()

                guard let httpResponse = response as? HTTPURLResponse else {
                    debugLog("Pronunciation audio response was not HTTP")
                    return
                }
                debugLog("Pronunciation audio HTTP status: \(httpResponse.statusCode)")
                debugLog("Pronunciation audio downloaded bytes: \(data.count)")

                guard (200...299).contains(httpResponse.statusCode), !data.isEmpty else {
                    debugLog("Pronunciation audio playback started: false")
                    return
                }

                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try session.setActive(true)

                let player = try AVAudioPlayer(data: data)
                guard player.prepareToPlay(), player.play() else {
                    debugLog("Pronunciation audio playback started: false")
                    return
                }

                audioPlayer = player
                debugLog("Pronunciation audio playback started: true")
            } catch is CancellationError {
                return
            } catch {
                debugLog("Pronunciation audio playback failed: \(error.localizedDescription)")
            }
        }
    }

    private func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        print(message())
#endif
    }
}
