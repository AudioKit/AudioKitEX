// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFAudio
import CAudioKitEX

/// A class to measure the proportion of buffer time
/// audio unit is spending in its render block
/// It can be used to measure CPU usage of the whole audio chain
/// by attaching it to `AVAudioEngine.outputNode`,
/// as well as any other audio unit.
public class RenderMeasurer {
    private let renderMeasurer = akRenderMeasurerCreate()
    private let node: AUAudioUnit
    private let token: Int
    private let timebaseRatio: Double

    public init(node: AUAudioUnit) {
        self.node = node
        var timebase = mach_timebase_info_data_t(numer: 0, denom: 0)
        let status = mach_timebase_info(&timebase)
        assert(status == 0)
        timebaseRatio = Double(timebase.numer) / Double(timebase.denom)
        let observer = akRenderMeasurerCreateObserver(renderMeasurer)
        self.token = node.token(byAddingRenderObserver: observer!)
    }

    deinit {
        node.removeRenderObserver(token)
    }

    /// Returns the proportion of buffer time
    /// audio unit is spending in its render block
    /// This is usually number between 0 - 1, but
    /// it can be higher in case of dropouts
    public func usage() -> Double {
        let sampleRate = node.outputBusses[0].format.sampleRate
        let currentUsage = akRenderMeasurerGetUsage(renderMeasurer)
        return Double(currentUsage) * timebaseRatio * sampleRate / 1_000_000_000
    }
}
