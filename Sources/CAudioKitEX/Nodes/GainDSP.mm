// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#include "DSPBase.h"
#include "ParameterRamper.h"

enum GainParameter : AUParameterAddress {
    GainParameterGain
};

struct GainDSP : DSPBase {
private:
    ParameterRamper gainRamp{1.0};

public:
    GainDSP() : DSPBase(1, true) {
        parameters[GainParameterGain] = &gainRamp;
    }

    void process(FrameRange range) override {
        for (auto i : range) {
            float gain = gainRamp.getAndStep();
            for (int channel = 0; channel < channelCount; ++channel) {
                outputSample(channel, i) = inputSample(channel, i) * gain;
            }
        }
    }
};

AK_REGISTER_DSP(GainDSP, "gain")
AK_REGISTER_PARAMETER(GainParameterGain)
