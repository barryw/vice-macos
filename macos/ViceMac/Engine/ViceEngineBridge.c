#include "ViceEngineBridge.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#include "vicemacbridge.h"

extern int main_program(int argc, char **argv);
extern void archdep_program_path_set_argv0(char *argv0);

typedef struct ViceEngineStartArguments {
    char *executablePath;
    char *dataDirectory;
} ViceEngineStartArguments;

static pthread_t engineThread;
static atomic_bool engineRunning = false;
static ViceEngineVideoFrameCallback videoFrameCallback = NULL;

static void videoFrameTrampoline(const vicemac_video_frame_t *frame, void *context)
{
    ViceEngineVideoFrame bridgedFrame;

    if (videoFrameCallback == NULL || frame == NULL) {
        return;
    }

    bridgedFrame.width = frame->width;
    bridgedFrame.height = frame->height;
    bridgedFrame.stride = frame->stride;
    bridgedFrame.pixelFormat = frame->pixel_format;
    bridgedFrame.sequence = frame->sequence;
    bridgedFrame.pixels = frame->pixels;

    videoFrameCallback(&bridgedFrame, context);
}

void ViceEngineSetVideoFrameCallback(ViceEngineVideoFrameCallback callback,
                                     void *context)
{
    videoFrameCallback = callback;
    vicemac_set_video_frame_callback(videoFrameTrampoline, context);
}

bool ViceEngineIsRunning(void)
{
    return atomic_load(&engineRunning);
}

void ViceEngineSendKeyEvent(int64_t key, int32_t modifiers, bool pressed)
{
    if (!atomic_load(&engineRunning)) {
        return;
    }

    (void)vicemac_queue_key_event((signed long)key, (int)modifiers, pressed ? 1 : 0);
}

void ViceEngineReleaseAllKeys(void)
{
    if (!atomic_load(&engineRunning)) {
        return;
    }

    (void)vicemac_queue_keyboard_clear();
}

static void *engineThreadMain(void *opaque)
{
    ViceEngineStartArguments *arguments = (ViceEngineStartArguments *)opaque;
    char *argv[] = {
        arguments->executablePath,
        "-default",
        "-directory",
        arguments->dataDirectory,
        "+sound",
        NULL
    };

    archdep_program_path_set_argv0(arguments->executablePath);
    (void)main_program(5, argv);

    atomic_store(&engineRunning, false);
    free(arguments->executablePath);
    free(arguments->dataDirectory);
    free(arguments);
    return NULL;
}

bool ViceEngineStartX64SC(const char *executablePath, const char *dataDirectory)
{
    ViceEngineStartArguments *arguments;
    bool expected = false;

    if (executablePath == NULL || dataDirectory == NULL) {
        return false;
    }

    if (!atomic_compare_exchange_strong(&engineRunning, &expected, true)) {
        return false;
    }

    arguments = (ViceEngineStartArguments *)calloc(1, sizeof(*arguments));
    if (arguments == NULL) {
        atomic_store(&engineRunning, false);
        return false;
    }

    arguments->executablePath = strdup(executablePath);
    arguments->dataDirectory = strdup(dataDirectory);
    if (arguments->executablePath == NULL || arguments->dataDirectory == NULL) {
        free(arguments->executablePath);
        free(arguments->dataDirectory);
        free(arguments);
        atomic_store(&engineRunning, false);
        return false;
    }

    if (pthread_create(&engineThread, NULL, engineThreadMain, arguments) != 0) {
        free(arguments->executablePath);
        free(arguments->dataDirectory);
        free(arguments);
        atomic_store(&engineRunning, false);
        return false;
    }

    pthread_detach(engineThread);
    return true;
}
