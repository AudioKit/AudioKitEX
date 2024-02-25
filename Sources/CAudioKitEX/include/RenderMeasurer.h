// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#pragma once

#include <AudioUnit/AudioUnit.h>

typedef struct RenderMeasurer* RenderMeasurerRef;

CF_EXTERN_C_BEGIN

RenderMeasurerRef akRenderMeasurerCreate(void);
AURenderObserver akRenderMeasurerCreateObserver(RenderMeasurerRef measurer);
double akRenderMeasurerGetUsage(RenderMeasurerRef measurer);

CF_EXTERN_C_END
