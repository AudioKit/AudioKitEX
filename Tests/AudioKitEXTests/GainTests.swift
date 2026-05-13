// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import Accelerate
import AudioKit
import AudioKitEX
import AVFoundation
import CAudioKitEX
import XCTest

class GainTests: XCTestCase {

    private var savedAudioFormat: AVAudioFormat!

    override func setUp() {
        super.setUp()
        savedAudioFormat = Settings.audioFormat
        Settings.sampleRate = 44100
    }

    override func tearDown() {
        Settings.audioFormat = savedAudioFormat
        super.tearDown()
    }

    // MARK: - Mono regression (would crash with Fader)

    func testMonoInputDoesNotCrash() {
        Settings.channelCount = 1

        let engine = AudioEngine()
        let oscillator = PlaygroundOscillator(waveform: Table(.triangle))
        engine.output = Gain(oscillator, gain: 1.0)

        oscillator.start()
        let audio = engine.startTest(totalDuration: 1.0)
        audio.append(engine.render(duration: 1.0))

        XCTAssertEqual(audio.format.channelCount, 1)
        XCTAssertFalse(audio.isSilent)
    }

    func testMonoGainHalvesAmplitude() {
        Settings.channelCount = 1

        let engine = AudioEngine()
        let oscillator = PlaygroundOscillator(waveform: Table(.triangle))
        let unityReference = rms(of: oscillator, gain: 1.0, engine: engine)

        let engine2 = AudioEngine()
        let oscillator2 = PlaygroundOscillator(waveform: Table(.triangle))
        let halved = rms(of: oscillator2, gain: 0.5, engine: engine2)

        XCTAssertEqual(halved, unityReference * 0.5, accuracy: unityReference * 0.05)
    }

    // MARK: - Stereo baseline

    func testStereoDefault() {
        Settings.channelCount = 2

        let engine = AudioEngine()
        let oscillator = PlaygroundOscillator(waveform: Table(.triangle))
        engine.output = Gain(oscillator, gain: 1.0)

        oscillator.start()
        let audio = engine.startTest(totalDuration: 1.0)
        audio.append(engine.render(duration: 1.0))

        XCTAssertEqual(audio.format.channelCount, 2)
        XCTAssertFalse(audio.isSilent)
    }

    func testStereoZeroGainIsSilent() {
        Settings.channelCount = 2

        let engine = AudioEngine()
        let oscillator = PlaygroundOscillator(waveform: Table(.triangle))
        engine.output = Gain(oscillator, gain: 0.0)

        oscillator.start()
        let audio = engine.startTest(totalDuration: 1.0)
        audio.append(engine.render(duration: 1.0))

        XCTAssertTrue(audio.isSilent)
    }

    // MARK: - Multichannel (4-channel quadraphonic)

    func testMultiChannelInputDoesNotCrash() throws {
        guard let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Quadraphonic) else {
            throw XCTSkip("Quadraphonic layout not supported on this platform")
        }
        Settings.audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channelLayout: layout)

        let engine = AudioEngine()
        let oscillator = PlaygroundOscillator(waveform: Table(.triangle))
        engine.output = Gain(oscillator, gain: 1.0)

        oscillator.start()
        let audio = engine.startTest(totalDuration: 1.0)
        audio.append(engine.render(duration: 1.0))

        XCTAssertEqual(audio.format.channelCount, 4)
        XCTAssertFalse(audio.isSilent)
    }

    // MARK: - Parameter ramping

    func testGainRampsSmoothly() {
        Settings.channelCount = 2

        let engine = AudioEngine()
        let oscillator = PlaygroundOscillator(waveform: Table(.triangle))
        let gain = Gain(oscillator, gain: 0.0)
        engine.output = gain

        oscillator.start()
        let audio = engine.startTest(totalDuration: 2.0)
        gain.automateGain(events: [
            AutomationEvent(targetValue: 1.0, startTime: 0, rampDuration: 2.0)
        ])
        audio.append(engine.render(duration: 2.0))

        XCTAssertFalse(audio.isSilent)

        // A linear gain ramp from 0 to 1 over the whole render should make the
        // final quarter dramatically louder than the first quarter.
        let quarter = Int(audio.frameLength) / 4
        let firstQuarterRMS = rms(audio, range: 0 ..< quarter)
        let lastQuarterRMS = rms(audio, range: (3 * quarter) ..< Int(audio.frameLength))
        XCTAssertLessThan(firstQuarterRMS, lastQuarterRMS * 0.4)
    }

    // MARK: - Helpers

    private func rms(of source: Node, gain: AUValue, engine: AudioEngine) -> Float {
        engine.output = Gain(source, gain: gain)
        (source as? PlaygroundOscillator)?.start()
        let audio = engine.startTest(totalDuration: 1.0)
        audio.append(engine.render(duration: 1.0))
        return rms(audio, range: 0 ..< Int(audio.frameLength))
    }

    private func rms(_ buffer: AVAudioPCMBuffer, range: Range<Int>) -> Float {
        guard let channelData = buffer.floatChannelData, !range.isEmpty else { return 0 }
        let channelCount = Int(buffer.format.channelCount)
        let length = vDSP_Length(range.count)
        var sum: Float = 0
        for channel in 0 ..< channelCount {
            var channelRMS: Float = 0
            vDSP_rmsqv(channelData[channel] + range.lowerBound, 1, &channelRMS, length)
            sum += channelRMS
        }
        return sum / Float(channelCount)
    }
}
