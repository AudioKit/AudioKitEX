// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/
#if !os(tvOS)

import XCTest
import AudioKit
import AudioKitEX

class CallbackInstrumentTests: XCTestCase {

    var instrument = CallbackInstrument()

    func testDefault() {
        let engine = AudioEngine()

        let expect = XCTestExpectation(description: "wait for callback")
        let expectedEvents: [MIDIEvent] = [
            .noteOn(60, velocity: .midi1(127), channel: 0),
            .noteOn(61, velocity: .midi1(127), channel: 0),
            .noteOn(62, velocity: .midi1(127), channel: 0)
        ]
        let expectedData: [[UInt8]] = [
            [0x90, 60, 127],
            [0x90, 61, 127],
            [0x90, 62, 127]
        ]

        var callbackData: [[UInt8]] = []

        instrument = CallbackInstrument { status, data1, data2 in
            callbackData.append([status, data1, data2])

            if callbackData.count == expectedData.count {
                expect.fulfill()
            }
        }

        engine.output = instrument

        for event in expectedEvents {
            instrument.scheduleMIDIEvent(event: event)
        }

        let audio = engine.startTest(totalDuration: 3.0)
        audio.append(engine.render(duration: 3.0))

        wait(for: [expect], timeout: 1.0)
        XCTAssertEqual(callbackData, expectedData)
    }

    func testEmptySequence() {
        let engine = AudioEngine()

        let expect = XCTestExpectation(description: "callback should not be called")
        /// No matter the expected data, the callback should not be called
        expect.isInverted = true
        let expectedData: [MIDIByte] = []
        var data: [MIDIByte] = []

        instrument = CallbackInstrument { status, data1, data2 in
            XCTFail("this callback should not be called")
            data.append(status)
            data.append(data1)
            data.append(data2)
        }

        engine.output = instrument

        let audio = engine.startTest(totalDuration: 3.0)
        audio.append(engine.render(duration: 3.0))

        wait(for: [expect], timeout: 1.0)
        /// If the callback does get called, this will fail our test, adding insult to injury
        XCTAssertEqual(data, expectedData)
    }
}
#endif
