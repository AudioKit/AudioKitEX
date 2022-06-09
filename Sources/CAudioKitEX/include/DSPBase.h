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

    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}

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
