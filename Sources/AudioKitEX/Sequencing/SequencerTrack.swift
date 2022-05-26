// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#if !os(tvOS)

import CAudioKitEX
import Foundation
import AudioKit

/// Audio player that loads a sample into memory
open class SequencerTrack {

    /// Node sequencer sends data to
    public var targetNode: Node? { didSet { addRenderObserver() }}

    /// Length of the track in beats
    public var length: Double = 4 { didSet { updateSequence() }}

    /// Speed of the track in beats per minute
    public var tempo: BPM = 120 { didSet { akSequencerEngineSetTempo(engine, tempo) }}

    /// Maximum number of times to play, ie. loop the track
    public var maximumPlayCount: Double = 1 { didSet { updateSequence() }}

    /// Is looping enabled?
    public var loopEnabled: Bool = true { didSet { updateSequence() }}

    /// Is the track currently playing?
    public var isPlaying: Bool { akSequencerEngineIsPlaying(engine) }

    /// Current position of the track
    public var currentPosition: Double { akSequencerEngineGetPosition(engine) }

    private var engine: SequencerEngineRef

    // MARK: - Initialization

    /// Initialize the track
    public init(targetNode: Node?) {
        self.targetNode = targetNode
        engine = akSequencerEngineCreate()
    }

    deinit {
        if let auAudioUnit = targetNode?.avAudioNode.auAudioUnit {
            if let token = renderObserverToken {
                auAudioUnit.removeRenderObserver(token)
            }
        }
        akSequencerEngineRelease(engine)
    }

    /// Start the track
    public func play() {
        akSequencerEngineSetPlaying(engine, true)
    }

    /// Start the track from the beginning
    public func playFromStart() {
        seek(to: 0)
        akSequencerEngineSetPlaying(engine, true)
    }

    /// Start the track after a certain delay in beats
    public func playAfterDelay(beats: Double) {
        seek(to: -1 * beats)
        akSequencerEngineSetPlaying(engine, true)
    }

    /// Stop playback
    public func stop() {
        akSequencerEngineSetPlaying(engine, false)
        akSequencerEngineStopPlayingNotes(engine)
    }

    /// Set the current position to the start of the track
    public func rewind() {
        seek(to: 0)
    }

    /// Move to a position in the track
    public func seek(to position: Double) {
        akSequencerEngineSeekTo(engine, position)
    }

    /// Sequence on this track
    public var sequence = NoteEventSequence() {
        willSet {
            if newValue.totalDuration >= length {
                Log("Warning: Note event sequence duration exceeds the bounds of the sequencer track")
                length = newValue.totalDuration + 0.01
                Log("Track length set to \(length) beats")
            }
        }
        didSet { updateSequence() }
    }

    /// Add a MIDI noteOn and noteOff to the track
    /// - Parameters:
    ///   - noteNumber: MIDI Note number to add
    ///   - velocity: Velocity of the note
    ///   - channel: Channel to place the note on
    ///   - position: Location in beats of the new note
    ///   - duration: Duration in beats of the new note
    public func add(noteNumber: MIDINoteNumber,
                    velocity: MIDIVelocity = 127,
                    channel: MIDIChannel = 0,
                    position: Double,
                    duration: Double) {
        sequence.add(noteNumber: noteNumber,
                     velocity: velocity,
                     channel: channel,
                     position: position,
                     duration: duration)
    }

    /// Add a MIDI event to the track
    /// - Parameters:
    ///   - event: Event to add
    ///   - position: Location in time in beats to add the event at
    public func add(event: MIDIEvent, position: Double) {
        sequence.add(event: event, position: position)
    }
    
    /// Remove the notes in the track
    public func clear() {
        sequence = NoteEventSequence()
    }

    /// Stop playing all the notes current in the "now playing" array.
    public func stopPlayingNotes() {
        akSequencerEngineStopPlayingNotes(engine)
    }

    private var renderObserverToken: Int?

    private func updateSequence() {
        guard let block = targetNode?.avAudioNode.auAudioUnit.scheduleMIDIEventBlock else {
            Log("Failed to get AUScheduleMIDIEventBlock")
            return
        }

        let settings = SequenceSettings(maximumPlayCount: Int32(maximumPlayCount),
                                        length: length,
                                        tempo: tempo,
                                        loopEnabled: loopEnabled,
                                        loopCount: 0)

        let orderedEvents = sequence.beatTimeOrderedEvents()
        orderedEvents.withUnsafeBufferPointer { (eventsPtr: UnsafeBufferPointer<SequenceEvent>) -> Void in

            akSequencerEngineUpdateSequence(engine,
                                            eventsPtr.baseAddress,
                                            orderedEvents.count,
                                            settings,
                                            Settings.sampleRate,
                                            block)


        }

        addRenderObserver()
    }

    private func addRenderObserver() {
        if renderObserverToken == nil {
            guard let observer = akSequencerGetRenderObserver(engine) else { return }
            guard let auAudioUnit = targetNode?.avAudioNode.auAudioUnit else { return }
            renderObserverToken = auAudioUnit.token(byAddingRenderObserver: observer)
        }
    }
}

#endif
