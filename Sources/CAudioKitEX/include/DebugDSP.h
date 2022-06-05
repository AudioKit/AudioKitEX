// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

#pragma once

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Activate or deactivate DSP kernel debugging.
void DebugDSPSetActive(bool active);

/// Update the hash at the selected slot with a new value.
void DebugDSP(int slot, float value);

/// Check the given slot against an expected hash. Call this at the
/// end of testing to ensure all calls to `DebugDSP` for the given
/// slot are what is expected.
bool DebugDSPCheck(int slot, const char* expected);

#ifdef __cplusplus
}
#endif


