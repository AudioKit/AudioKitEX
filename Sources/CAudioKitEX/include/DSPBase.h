// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#pragma once

#import "Interop.h"
#import <AudioToolbox/AudioToolbox.h>

#include <stdarg.h>

CF_EXTERN_C_BEGIN

DSPRef akCreateDSP(OSType code);
AUParameterAddress akGetParameterAddress(const char* name);

AUInternalRenderBlock internalRenderBlockDSP(DSPRef pDSP);

size_t inputBusCountDSP(DSPRef pDSP);
bool canProcessInPlaceDSP(DSPRef pDSP);

void setBufferDSP(DSPRef pDSP, AudioBufferList* buffer, size_t busIndex);
void allocateRenderResourcesDSP(DSPRef pDSP, uint32_t channelCount, double sampleRate);
void deallocateRenderResourcesDSP(DSPRef pDSP);
void resetDSP(DSPRef pDSP);

void setParameterValueDSP(DSPRef pDSP, AUParameterAddress address, AUValue value);
AUValue getParameterValueDSP(DSPRef pDSP, AUParameterAddress address);

void setBypassDSP(DSPRef pDSP, bool bypassed);
bool getBypassDSP(DSPRef pDSP);

void initializeConstantDSP(DSPRef pDSP, AUValue value);

void setWavetableDSP(DSPRef pDSP, const float* table, size_t length, int index);

void deleteDSP(DSPRef pDSP);

/// Reset random seed to ensure deterministic results in tests.
void akSetSeed(unsigned int);

CF_EXTERN_C_END

#ifdef __cplusplus

#include <atomic>
#import <vector>

struct FrameRange {
    AUAudioFrameCount start;
    AUAudioFrameCount count;

    struct iterator {
        AUAudioFrameCount index;

        AUAudioFrameCount operator*() const {
            return index;
        }

        bool operator!=(const iterator& rhs) const {
            return index != rhs.index;
        }

        iterator& operator++() {
            ++index;
            return *this;
        }
    };

    iterator begin() {
        return {start};
    }

    iterator end() {
        return {start+count};
    }
};

/**
 Base class for DSPKernels. Many of the methods are virtual, because the base AudioUnit class
 does not know the type of the subclass at compile time.
 */

struct DSPBase {

private:

    std::vector<AudioBufferList*> internalBufferLists;
    
protected:

    int channelCount;
    double sampleRate;

    bool isInitialized = false;

    // current time in samples
    AUEventSampleTime now = 0;

    static constexpr int maxParameters = 128;
    
    class ParameterRamper* parameters[maxParameters];

    std::vector<AudioBufferList*> inputBufferLists;
    AudioBufferList* outputBufferList = nullptr;

    inline float& inputSample(int channel, AUAudioFrameCount frame) {
        return ((float *)inputBufferLists[0]->mBuffers[channel].mData)[frame];
    }

    inline float& input2Sample(int channel, AUAudioFrameCount frame) {
        return ((float *)inputBufferLists[1]->mBuffers[channel].mData)[frame];
    }

    inline float& outputSample(int channel, AUAudioFrameCount frame) {
        return ((float *)outputBufferList->mBuffers[channel].mData)[frame];
    }

    void stepRampsBy(AUAudioFrameCount frames);

    void zeroOutput(AUAudioFrameCount frames, AUAudioFrameCount bufferOffset);

    void cloneFirstChannel(FrameRange range);

public:
    
    DSPBase(int inputBusCount=1, bool canProcessInPlace=false);
    
    /// Virtual destructor allows child classes to be deleted with only DSPBase *pointer
    virtual ~DSPBase();
    
    AUInternalRenderBlock internalRenderBlock();

    const bool bCanProcessInPlace;

    std::atomic<bool> isStarted{true};
    
    void setBuffer(AudioBufferList* buffer, size_t busIndex);
    size_t getInputBusCount() const { return inputBufferLists.size(); }

    /// Render function.
    virtual void process(FrameRange range) = 0;
    
    /// Uses the ParameterAddress as a key
    virtual void setParameter(AUParameterAddress address, float value, bool immediate = false);

    /// Uses the ParameterAddress as a key
    virtual float getParameter(AUParameterAddress address);

    /// Get the DSP into initialized state
    virtual void reset() {}

    /// Common for oscillators
    virtual void setWavetable(const float* table, size_t length, int index) {}

    /// Multiple waveform oscillators
    virtual void setupIndividualWaveform(uint32_t waveform, uint32_t size) {}

    virtual void setIndividualWaveformValue(uint32_t waveform, uint32_t index, float value) {}
    
    /// override this if your DSP kernel allocates memory or requires the session sample rate for initialization
    virtual void init(int channelCount, double sampleRate);

    /// override this if your DSP kernel allocates memory; free it here
    virtual void deinit();

    /// Override to handle midi events manually. By default this calls noteOn and noteOff
    /// to save you from having to parse MIDI. Eventually, we'll add more.
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {

        if (midiEvent.length != 3) return;
        uint8_t status = midiEvent.data[0] & 0xF0;
        uint8_t channel = midiEvent.data[0] & 0x0F;
        switch (status) {
            case MIDI_NOTE_ON : {
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;

                // A note on message with velocity 0 is actually a note off!
                // Who woulda thunk?!
                // See https://www.midi.org/forum/228-writing-midi-software-send-note-off,-or-zero-velocity-note-on

                if (veloc == 0) {
                    noteOff(note, veloc);
                } else {
                    noteOn(note, veloc);
                }
                break;
            }
            case MIDI_NOTE_OFF : {
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127) break;
                noteOff(note, veloc);
                break;
            }
        }

    }

    /// Override to handle MIDI note on messages.
    virtual void noteOn(uint8_t note, uint8_t velocity) {}

    /// Override to handle MIDI note off messages. Velocity can refer to a release envelope.
    virtual void noteOff(uint8_t note, uint8_t velocity) {}

    /// Pointer to a factory function.
    using CreateFunction = DSPRef (*)();

    /// Adds a function to create a subclass by name.
    static void addCreateFunction(const char* name, CreateFunction func);

    /// Registers a parameter.
    static void addParameter(const char* paramName, AUParameterAddress address);

    /// Create a subclass by name.
    static DSPRef create(const char* name);

    virtual void startRamp(const AUParameterEvent& event);
    
private:

    /**
     Handles the event list processing and rendering loop. Should be called from AU renderBlock
     From Apple Example code
     */
    void processWithEvents(AudioTimeStamp const *timestamp,
                           AUAudioFrameCount frameCount,
                           AURenderEvent const *events);

    void processOrBypass(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset);
    
    void handleOneEvent(AURenderEvent const *event);
    
    void performAllSimultaneousEvents(AUEventSampleTime now, AURenderEvent const *&event);

    
};

/// Registers a creation function when initialized.
template<class T>
struct DSPRegistration {
    static DSPRef construct() {
        return new T();
    }

    DSPRegistration(const char* name) {
        DSPBase::addCreateFunction(name, construct);
    }
};

/// Convenience macro for registering a subclass of DSPBase.
///
/// You'll want to do `AK_REGISTER_DSP(AKMyClass, componentSubType)`
#define AK_REGISTER_DSP(ClassName, Code) DSPRegistration<ClassName> __register##ClassName(Code);

struct ParameterRegistration {
    ParameterRegistration(const char* name, AUParameterAddress address) {
        DSPBase::addParameter(name, address);
    }
};

#define AK_REGISTER_PARAMETER(ParamAddress) ParameterRegistration __register_param_##ParamAddress(#ParamAddress, ParamAddress);

#endif
