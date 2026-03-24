//
//  DynamicGraphTests.swift
//  AudioKitEX
//
//  Created by Taylor Holliday on 3/23/26.
//

import Testing
import AudioKit
import AudioKitEX
import AVFoundation
import Accelerate
import CAudioKitEX

/// Manages local audio file playback using `AudioKit` with `AudioKitEX` fades.
@MainActor
final class AudioKitFilePlayer {
    private struct ActivePlaybackNode {
        let player: AudioPlayer
        let fader: Fader
        let panMixer: Mixer
        let instrument: Instrument

        var id: ObjectIdentifier {
            ObjectIdentifier(player.playerNode)
        }
    }

    let levelsHolder = LevelsHolder()

    private let audioEngine = AudioEngine()
    private let masterMixer = Mixer(name: "AudioKitFilePlayer Master")
    private let instrumentMixers = Dictionary(
        uniqueKeysWithValues: Instrument.allCases.map { instrument in
            (instrument, Mixer(name: "\(instrument.rawValue) Mixer"))
        }
    )
    private var levelsTap: RawBufferTap?

    private var activePlaybackNodes: [ObjectIdentifier: ActivePlaybackNode] = [:]
    private var engineIsRunning = false

    var isRunning: Bool {
        engineIsRunning
    }

    init() {
        setupInstrumentMixers()
        audioEngine.output = masterMixer
        let levelsTap = RawBufferTap(
            masterMixer,
            bufferSize: 1024,
            callbackQueue: .global(qos: .userInitiated),
            handler: Self.makeLevelsTap(holder: levelsHolder)
        )
        self.levelsTap = levelsTap
        levelsTap.start()
    }

    func startPlayback() {
        do {
            if !engineIsRunning {
                try audioEngine.start()
                engineIsRunning = true
                Self.log("AudioEngine started")
            }
        } catch {
            Self.log("Error starting AudioEngine: \(error)")
        }
    }

    func stopPlayback() {
        stopAllRunningPlayers()
    }

    func pausePlayback() {
        stopAllRunningPlayers()
        audioEngine.pause()
        engineIsRunning = false
    }

    func reset() {
        stopAllRunningPlayers()
        audioEngine.stop()
        levelsTap?.stop()
        engineIsRunning = false
    }

    func setOutputVolume(_ outputVolume: Float) {
        masterMixer.volume = outputVolume
    }

    func updateActiveInstruments(_ activeInstruments: Set<Instrument>) {
        for (instrument, mixer) in instrumentMixers {
            mixer.volume = activeInstruments.contains(instrument) ? 1.0 : 0.0
        }
    }

    func scheduleFilePlayback(
        _ audioFile: AVAudioFile,
        fileName: String,
        instrument: Instrument,
        gain: Float,
        startTime: Double,
        endTime: Double,
        fileOffset: Double,
        fadeInDuration: Double,
        fadeOutDuration: Double,
        pan: Float
    ) {
        guard isRunning else { return }

        guard let instrumentMixer = instrumentMixers[instrument] else {
            Self.log("Missing mixer for instrument \(instrument.rawValue)")
            return
        }

        let player = AudioPlayer()
        let fader = Fader(player, gain: gain)
        let panMixer = Mixer(fader, name: "\(fileName) Pan")
        let activeNode = ActivePlaybackNode(
            player: player,
            fader: fader,
            panMixer: panMixer,
            instrument: instrument
        )

        do {
            try player.load(file: audioFile, buffered: false)
        } catch {
            Self.log("Could not load audio file for \(fileName): \(error)")
            return
        }

        panMixer.pan = AUValue(pan)
        instrumentMixer.addInput(panMixer)
        activePlaybackNodes[activeNode.id] = activeNode

        let playDuration = max(0, endTime - startTime)
        let effectiveGain = AUValue(max(0, gain))

        if fadeInDuration > 0 {
            fader.gain = 0
        } else {
            fader.gain = effectiveGain
        }

        let automationEvents = makeGainAutomationEvents(
            targetGain: effectiveGain,
            playDuration: playDuration,
            fadeInDuration: fadeInDuration,
            fadeOutDuration: fadeOutDuration
        )

        if !automationEvents.isEmpty {
            fader.automateGain(events: automationEvents)
        }

        player.completionHandler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.cleanupPlaybackNode(id: activeNode.id, fileName: fileName)
            }
        }

        player.play(from: fileOffset, to: fileOffset + playDuration)
    }

    private func makeGainAutomationEvents(
        targetGain: AUValue,
        playDuration: Double,
        fadeInDuration: Double,
        fadeOutDuration: Double
    ) -> [AutomationEvent] {
        var events: [AutomationEvent] = []

        if fadeInDuration > 0 {
            events.append(
                AutomationEvent(
                    targetValue: targetGain,
                    startTime: 0,
                    rampDuration: Float(fadeInDuration)
                )
            )
        }

        if fadeOutDuration > 0 {
            let fadeOutDelay = playDuration - fadeOutDuration

            if fadeOutDelay > 0 {
                events.append(
                    AutomationEvent(
                        targetValue: 0,
                        startTime: Float(fadeOutDelay),
                        rampDuration: Float(fadeOutDuration)
                    )
                )
            }
        }

        return events
    }

    private func setupInstrumentMixers() {
        for mixer in instrumentMixers.values {
            masterMixer.addInput(mixer)
        }
    }

    private func stopAllRunningPlayers() {
        let activeNodes = Array(activePlaybackNodes.values)

        for activeNode in activeNodes {
            cleanupPlaybackNode(id: activeNode.id)
        }
    }

    private func cleanupPlaybackNode(id: ObjectIdentifier, fileName: String? = nil) {
        guard let activeNode = activePlaybackNodes.removeValue(forKey: id) else {
            return
        }

        activeNode.player.stop()
        activeNode.fader.stopAutomation()
        activeNode.panMixer.volume = 0
        instrumentMixers[activeNode.instrument]?.removeInput(activeNode.panMixer)

        if let fileName {
            Self.log("Detaching AudioKit player node for \(fileName)")
        }
    }

    nonisolated private static func makeLevelsTap(holder: LevelsHolder) -> AVAudioNodeTapBlock {
        return { buffer, _ in
            guard let floatData = buffer.floatChannelData else {
                log("Tap received nil floatChannelData")
                return
            }

            let channelCount = Int(buffer.format.channelCount)
            let length = UInt(buffer.frameLength)

            for channelIndex in 0..<channelCount {
                let data = floatData[channelIndex]

                var rms: Float = 0
                vDSP_rmsqv(data, 1, &rms, length)

                holder.setLevel(rms, channel: channelIndex)
            }
        }
    }
}

extension AudioKitFilePlayer {
    nonisolated private static func log(_ message: @autoclosure () -> String) {
        print("[AudioKitFilePlayer] \(message())")
    }
}

enum Instrument: String, CaseIterable, Hashable {
    case waves
}

final class LevelsHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var levels: [Int: Float] = [:]

    func setLevel(_ level: Float, channel: Int) {
        lock.lock()
        levels[channel] = level
        lock.unlock()
    }
}


@MainActor
@Test
func testAudioKitFilePlayerCanScheduleLocalMP3() throws {
    let testFileURL = Bundle.module.url(forResource: "12345", withExtension: "wav", subdirectory: "TestResources")!
    let audioFile = try AVAudioFile(forReading: testFileURL)

    let player = AudioKitFilePlayer()
    player.startPlayback()

    #expect(player.isRunning)

    player.scheduleFilePlayback(
        audioFile,
        fileName: testFileURL.lastPathComponent,
        instrument: .waves,
        gain: 1.0,
        startTime: 0,
        endTime: min(audioFile.duration, 0.25),
        fileOffset: 0,
        fadeInDuration: 0.05,
        fadeOutDuration: 0.05,
        pan: 0
    )
}

