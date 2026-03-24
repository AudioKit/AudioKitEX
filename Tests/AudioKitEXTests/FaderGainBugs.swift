//
//  FaderGainBugs.swift
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


/// Minimal repro: Fader.init calls AudioUnitSetParameter on an AU that hasn't been
/// added to an engine, so the C-level AudioUnit doesn't recognise the parameter address
/// and returns kAudioUnitErr_InvalidParameter (-10878).
///
/// CheckError logs but doesn't throw, so we call the C API directly to prove
/// the parameter write fails on an unconnected AudioUnit.
@MainActor
@Test
func testFaderInitWithoutEngine() throws {
    let mixer = Mixer()
    let fader = Fader(mixer, gain: 1.0)

    // The Fader's underlying AudioUnit is not connected to any engine yet.
    // Prove that setting a parameter on it returns kAudioUnitErr_InvalidParameter.
    let avAudioUnit = fader.avAudioNode as! AVAudioUnit
    let au = avAudioUnit.audioUnit
    let rightGainAddress = akGetParameterAddress("FaderParameterRightGain")
    let status = AudioUnitSetParameter(au, AudioUnitParameterID(rightGainAddress), kAudioUnitScope_Global, 0, 1.0, 0)
    #expect(status == kAudioUnitErr_InvalidParameter,
            "Expected kAudioUnitErr_InvalidParameter (-10878) but got \(status)")
}

/// Prove that a non-default gain passed to Fader.init is silently lost at the
/// C level. The Swift-side parameter.value holds 0.5, but after the node is
/// connected to a running engine the DSP kernel still sees the default (1.0).
@MainActor
@Test
func testFaderGainLostAfterConnection() throws {
    let engine = AudioEngine()
    let masterMixer = Mixer(name: "Master")
    engine.output = masterMixer

    let inputMixer = Mixer()
    let fader = Fader(inputMixer, gain: 0.5)

    // Swift side thinks gain is 0.5
    #expect(fader.$leftGain.value == 0.5, "Swift-side leftGain should be 0.5")

    // Now connect to the running engine — this calls makeAVConnections
    masterMixer.addInput(fader)
    try engine.start()

    // Read back from both the Swift AUParameter and C-level AudioUnit
    let avAudioUnit = fader.avAudioNode as! AVAudioUnit
    let au = avAudioUnit.audioUnit
    let leftGainAddress = akGetParameterAddress("FaderParameterLeftGain")

    // Swift AUParameter thinks it's 0.5
    let swiftValue = fader.$leftGain.value
    #expect(swiftValue == 0.5, "Swift-side leftGain should be 0.5 — got \(swiftValue)")

    // C-level AudioUnit does NOT have 0.5
    var cValue: AudioUnitParameterValue = -1
    AudioUnitGetParameter(au, AudioUnitParameterID(leftGainAddress), kAudioUnitScope_Global, 0, &cValue)
    #expect(cValue != 0.5,
            "C-level gain should NOT be 0.5 — the init-time set was lost (got \(cValue))")

    engine.stop()
}
