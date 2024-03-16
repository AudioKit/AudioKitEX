// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#include "DSPBase.h"
#import "CAudioKit.h"
#include <mach/mach_time.h>
#include "RenderMeasurer.h"

struct RenderMeasurer {

public:
    RenderMeasurer() {
        usage = 0;
    }

    static RenderMeasurer *_Nonnull create() {
        RenderMeasurer* measurer = new RenderMeasurer();
        return measurer;
    }

    _Nonnull AURenderObserver createObserver() {
        auto sharedThis = std::shared_ptr<RenderMeasurer>(this);
        return ^void(AudioUnitRenderActionFlags actionFlags,
                     const AudioTimeStamp *timestamp,
                     AUAudioFrameCount frameCount,
                     NSInteger outputBusNumber)
        {
            uint64_t time = mach_absolute_time();
            if (actionFlags == kAudioUnitRenderAction_PreRender) {
                sharedThis->startTime = time;
                return;
            }
            uint64_t endTime = time;
            sharedThis->usage.store((double)(endTime - sharedThis->startTime) / (double)frameCount);
        };
    }

    double currentUsage() {
        return usage.load();
    }

private:
    std::atomic<double> usage;
    uint64_t startTime;
};

RenderMeasurerRef akRenderMeasurerCreate(void) {
    return new RenderMeasurer();
}

AURenderObserver akRenderMeasurerCreateObserver(RenderMeasurerRef measurer) {
    return measurer->createObserver();
}

double akRenderMeasurerGetUsage(RenderMeasurerRef measurer) {
    return measurer->currentUsage();
}
