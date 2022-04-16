// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#pragma once

#import <AVFoundation/AVFoundation.h>
#import "Interop.h"

/// Sequence Event
typedef struct {
    uint8_t status;
    uint8_t data1;
    uint8_t data2;
    double beat;
} SequenceEvent;

/// Sequence Note
typedef struct {
    SequenceEvent noteOn;
    SequenceEvent noteOff;
} SequenceNote;

/// Sequence Settings
typedef struct {
    int maximumPlayCount;
    double length;
    double tempo;
    bool loopEnabled;
    uint loopCount;
} SequenceSettings;

typedef struct SequencerEngine* SequencerEngineRef;

CF_EXTERN_C_BEGIN

/// Creates the audio-thread-only state for the sequencer.
SequencerEngineRef akSequencerEngineCreate(void);

/// Release ownership of the sequencer. Sequencer is deallocated when no render observers are live.
void akSequencerEngineRelease(SequencerEngineRef engine);

/// Updates the sequence atomically.
void akSequencerEngineUpdateSequence(SequencerEngineRef engine,
                                     const SequenceEvent* events,
                                     size_t eventCount,
                                     SequenceSettings settings,
                                     double sampleRate,
                                     AUScheduleMIDIEventBlock block);

/// Returns function to be called on audio thread.
AURenderObserver akSequencerGetRenderObserver(SequencerEngineRef engine);

/// Returns the sequencer playhead position in beats.
double akSequencerEngineGetPosition(SequencerEngineRef engine);

/// Move the playhead to a location in beats.
void akSequencerEngineSeekTo(SequencerEngineRef engine, double position);

void akSequencerEngineSetPlaying(SequencerEngineRef engine, bool playing);

bool akSequencerEngineIsPlaying(SequencerEngineRef engine);

/// Stop all notes currently playing.
void akSequencerEngineStopPlayingNotes(SequencerEngineRef engine);

/// Update sequencer tempo.
void akSequencerEngineSetTempo(SequencerEngineRef engine, double tempo);

CF_EXTERN_C_END
