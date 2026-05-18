#ifndef VICE_ENGINE_BRIDGE_H
#define VICE_ENGINE_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ViceEngineVideoFrame {
    uint32_t width;
    uint32_t height;
    uint32_t stride;
    uint32_t pixelFormat;
    uint64_t sequence;
    const uint8_t *pixels;
} ViceEngineVideoFrame;

typedef void (*ViceEngineVideoFrameCallback)(const ViceEngineVideoFrame *frame,
                                             void *context);

void ViceEngineSetVideoFrameCallback(ViceEngineVideoFrameCallback callback,
                                     void *context);
bool ViceEngineStartX64SC(const char *executablePath, const char *dataDirectory);
bool ViceEngineIsRunning(void);
void ViceEngineSendKeyEvent(int64_t key, int32_t modifiers, bool pressed);
void ViceEngineReleaseAllKeys(void);

#ifdef __cplusplus
}
#endif

#endif
