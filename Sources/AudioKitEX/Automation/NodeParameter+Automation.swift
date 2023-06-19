// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AudioKit
import AVFoundation
import CAudioKitEX

// TODO: need unit tests (were moved to SoundpipeAudioKit)

/// Automation functions rely on CAudioKit, so they are in this extension in case we want to
/// make a pure-swift AudioKit.
extension NodeParameter {
    
    /// Begin automation of the parameter.
    ///
    /// If `startTime` is nil, the automation will be scheduled as soon as possible.
    ///
    /// - Parameter events: automation curve
    /// - Parameter startTime: optional time to start automation
    public func automate(events: [AutomationEvent], startTime: AUEventSampleTime = AUEventSampleTimeImmediate) {

        stopAutomation()
        
        events.withUnsafeBufferPointer { automationPtr in
            
            guard let automationBaseAddress = automationPtr.baseAddress else { return }
            
            guard let observer = ParameterAutomationGetRenderObserver(parameter.address,
                                                                      auAudioUnit!.scheduleParameterBlock,
                                                                      Float(44100),
                                                                      Float(startTime),
                                                                      automationBaseAddress,
                                                                      events.count) else { return }
            
            renderObserverToken = auAudioUnit!.token(byAddingRenderObserver: observer)
        }
    }

    /// Stop automation
    public func stopAutomation() {
        if let token = renderObserverToken {
            auAudioUnit?.removeRenderObserver(token)
        }
    }

    /// Ramp from a source value (which is ramped to over 20ms) to a target value
    ///
    /// - Parameters:
    ///   - start: initial value
    ///   - target: destination value
    ///   - duration: duration to ramp to the target value in seconds
    public func ramp(from start: AUValue, to target: AUValue, duration: Float) {
        ramp(to: start, duration: 0.02, delay: 0)
        ramp(to: target, duration: duration, delay: 0.02)
    }
    
}
