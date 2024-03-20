// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AudioKit
import AudioKitEX
import XCTest
import AVFAudio
import CAudioKitEX

class RenderMeasurerTests: XCTestCase {
    let engine = AVAudioEngine()
    var sleepProporition: Float = 1
    lazy var source = AVAudioSourceNode { _, _, frameCount, _ -> OSStatus in
        usleep(UInt32(Float(frameCount) / 44100 * 1000 * 1000 * self.sleepProporition))
        return noErr
    }

    override func setUp() {
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: nil)
        try! engine.start()
    }

    override func tearDown() {
        engine.stop()
    }

    func testUsageHigherThen1() async throws {
        self.sleepProporition = 1
        let measurer = RenderMeasurer(node: source.auAudioUnit)
        for _ in 1...10 {
            try await Task.sleep(nanoseconds: 1_000_000_00)
            XCTAssertGreaterThanOrEqual(measurer.usage(), 1)
        }
    }

    func testUsageHigherThen05() async throws {
        self.sleepProporition = 0.5
        let measurer = RenderMeasurer(node: source.auAudioUnit)
        for _ in 1...10 {
            try await Task.sleep(nanoseconds: 1_000_000_00)
            let usage = measurer.usage()
            XCTAssertGreaterThanOrEqual(usage, 0.5)
            XCTAssertLessThanOrEqual(usage, 1)
        }
    }
}
