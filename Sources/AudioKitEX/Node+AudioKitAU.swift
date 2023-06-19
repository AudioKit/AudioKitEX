// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation
import CAudioKitEX
import AudioKit

/// Convenience for getting the AudioKitAU from a Node.
extension Node {

    /// Audio Unit for AudioKit
    public var akau: AudioKitAU {
        guard let akau = (auAudioUnit as? AudioKitAU) else {
            fatalError("Wrong audio unit type.")
        }
        return akau
    }
}

public func registerAndInstantiateAU(componentDescription: AudioComponentDescription) -> AUAudioUnit {

    AUAudioUnit.registerSubclass(AudioKitAU.self,
                                 as: componentDescription,
                                 name: "Local internal AU",
                                 version: .max)

    var result: AUAudioUnit!
    let runLoop = RunLoop.current
    AUAudioUnit.instantiate(with: componentDescription) { auAudioUnit, _ in
        guard let au = auAudioUnit else { fatalError("Unable to instantiate AUAudioUnit") }
        runLoop.perform {
            result = au
        }
    }
    while result == nil {
        runLoop.run(until: .now + 0.01)
    }
    return result
}

/// Create a generator for the given unique identifier
/// - Parameter code: Unique four letter identifier
public func instantiateAU(generator code: String) -> AUAudioUnit {
    registerAndInstantiateAU(componentDescription: AudioComponentDescription(generator: code))
}

/// Create an instrument for the given unique identifier
/// - Parameter code: Unique four letter identifier
public func instantiateAU(instrument code: String) -> AUAudioUnit {
    registerAndInstantiateAU(componentDescription: AudioComponentDescription(instrument: code))
}

/// Create an effect for the given unique identifier
/// - Parameter code: Unique four letter identifier
public func instantiateAU(effect code: String) -> AUAudioUnit {
    registerAndInstantiateAU(componentDescription: AudioComponentDescription(effect: code))
}

/// Create a mixer for the given unique identifier
/// - Parameter code: Unique four letter identifier
public func instantiateAU(mixer code: String) -> AUAudioUnit {
    registerAndInstantiateAU(componentDescription: AudioComponentDescription(mixer: code))
}

