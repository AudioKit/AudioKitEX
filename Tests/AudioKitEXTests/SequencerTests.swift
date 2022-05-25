// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#if !os(tvOS)
import XCTest
import AudioKit
import AVFoundation
import AudioKitEX

class SequencerTests: XCTestCase {
    func testAddNoteWhilePlaying() {
        let engine = AudioEngine()
        let sampler = AppleSampler()
        let sampleURL = Bundle.module.url(forResource: "TestResources/middleC", withExtension: "wav")
        guard let sampleURL = sampleURL else {
            Log("Problem getting sample URL")
            return
        }
        let audioFile = try? AVAudioFile(forReading: sampleURL)
        guard let audioFile = audioFile else {
            Log("Problem getting sample file")
            return
        }
        try? sampler.loadAudioFile(audioFile)
        let sequencer = Sequencer(targetNode: sampler)
        engine.output = sampler
        try? engine.start()
        sequencer.addTrack(for: sampler)
        sequencer.play()
        XCTAssertTrue(sequencer.isPlaying)
        sequencer.tracks[0].add(noteNumber: 60, position: 0.0, duration: 1.0)
        sequencer.tracks[1].add(noteNumber: 64, position: 0.0, duration: 1.0)
        sleep(2)
    }
}
#endif
