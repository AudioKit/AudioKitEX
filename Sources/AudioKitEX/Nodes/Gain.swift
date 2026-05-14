// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation
import CAudioKitEX
import AudioKit

/// Multi-channel safe gain node. Applies a single ramped gain factor to every
/// channel of the input buffer, regardless of channel count. Unlike `Fader`
/// (which hard-codes stereo and crashes on mono input), this node iterates
/// over the actual channel count reported by the audio unit.
public class Gain: Node {

    let input: Node

    /// Connected nodes
    public var connections: [Node] { [input] }

    /// Underlying AVAudioNode
    public var avAudioNode = instantiate(effect: "gain")

    // MARK: - Parameters

    /// Allow gain to be any non-negative number
    public static let gainRange: ClosedRange<AUValue> = 0.0 ... Float.greatestFiniteMagnitude

    /// Specification details for gain
    public static let gainDef = NodeParameterDef(
        identifier: "gain",
        name: "Gain",
        address: akGetParameterAddress("GainParameterGain"),
        defaultValue: 1,
        range: Gain.gainRange,
        unit: .linearGain)

    /// Amplification Factor applied to all channels
    @Parameter(gainDef) public var gain: AUValue

    /// Amplification Factor in dB - 0 is unity (gain = 1.0)
    public var dB: AUValue {
        get { 20.0 * log10(gain) }
        set { gain = pow(10.0, newValue / 20.0) }
    }

    // MARK: - Initialization

    /// Initialize this gain node
    ///
    /// - Parameters:
    ///   - input: Node whose output will be amplified
    ///   - gain: Amplification factor (Default: 1, Minimum: 0)
    ///
    public init(_ input: Node, gain: AUValue = 1) {
        self.input = input

        setupParameters()

        self.gain = gain
    }

    // MARK: - Automation

    /// Gain automation helper
    /// - Parameters:
    ///   - events: List of events
    ///   - startTime: start time
    public func automateGain(events: [AutomationEvent], startTime: AVAudioTime? = nil) {
        $gain.automate(events: events, startTime: startTime)
    }

    /// Stop automation
    public func stopAutomation() {
        $gain.stopAutomation()
    }
}
