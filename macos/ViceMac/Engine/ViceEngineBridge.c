#include "ViceEngineBridge.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "vicemacbridge.h"

extern int main_program(int argc, char **argv);
extern void archdep_program_path_set_argv0(char *argv0);

typedef struct ViceEngineStartArguments {
    char *executablePath;
    char *dataDirectory;
    int32_t sidModel;
    bool soundEnabled;
    int32_t soundVolume;
    int32_t speedPercent;
    bool warpEnabled;
    char *basicROM;
    char *kernalROM;
    char *characterROM;
} ViceEngineStartArguments;

static pthread_t engineThread;
static atomic_bool engineRunning = false;
static ViceEngineVideoFrameCallback videoFrameCallback = NULL;
static ViceEngineDriveStatusCallback driveStatusCallback = NULL;
static ViceEngineCartridgeStatusCallback cartridgeStatusCallback = NULL;

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

static void driveStatusTrampoline(const vicemac_drive_status_t *status, void *context)
{
    ViceEngineDriveStatus bridgedStatus;

    if (driveStatusCallback == NULL || status == NULL) {
        return;
    }

    bridgedStatus.unit = status->unit;
    bridgedStatus.enabled = status->enabled != 0;
    bridgedStatus.driveType = status->drive_type;
    bridgedStatus.ledColor = status->led_color;
    bridgedStatus.ledIntensity = status->led_pwm1;
    bridgedStatus.errorIntensity = status->led_pwm2;
    bridgedStatus.trackValid = status->track_valid != 0;
    bridgedStatus.track = status->track;
    bridgedStatus.halfTrack = status->half_track;
    bridgedStatus.diskSide = status->disk_side;
    bridgedStatus.sectorValid = status->sector_valid != 0;
    bridgedStatus.sector = status->sector;
    bridgedStatus.operation = status->operation;
    bridgedStatus.driveStatusCode = status->drive_status_code;
    bridgedStatus.driveStatusText = status->drive_status_text;
    bridgedStatus.imagePath = status->image_path;

    driveStatusCallback(&bridgedStatus, context);
}

static void cartridgeStatusTrampoline(const vicemac_cartridge_status_t *status, void *context)
{
    ViceEngineCartridgeStatus bridgedStatus;

    if (cartridgeStatusCallback == NULL || status == NULL) {
        return;
    }

    bridgedStatus.attached = status->attached != 0;
    bridgedStatus.cartridgeID = status->cartridge_id;
    bridgedStatus.cartridgeFlags = status->cartridge_flags;
    bridgedStatus.romSize = status->rom_size;
    bridgedStatus.chipCount = status->chip_count;
    bridgedStatus.bankCount = status->bank_count;
    bridgedStatus.cartridgeName = status->cartridge_name;
    bridgedStatus.imagePath = status->image_path;

    cartridgeStatusCallback(&bridgedStatus, context);
}

void ViceEngineSetVideoFrameCallback(ViceEngineVideoFrameCallback callback,
                                     void *context)
{
    videoFrameCallback = callback;
    vicemac_set_video_frame_callback(videoFrameTrampoline, context);
}

void ViceEngineSetDriveStatusCallback(ViceEngineDriveStatusCallback callback,
                                      void *context)
{
    driveStatusCallback = callback;
    vicemac_set_drive_status_callback(driveStatusTrampoline, context);
}

void ViceEngineSetCartridgeStatusCallback(ViceEngineCartridgeStatusCallback callback,
                                          void *context)
{
    cartridgeStatusCallback = callback;
    vicemac_set_cartridge_status_callback(cartridgeStatusTrampoline, context);
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

bool ViceEngineSetIntResource(const char *name, int32_t value)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_resource_int(name, (int)value) != 0;
}

bool ViceEngineSetStringResource(const char *name, const char *value)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_resource_string(name, value) != 0;
}

bool ViceEngineSetJoystickValue(uint32_t port, uint32_t value)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_joystick_value(port, value) != 0;
}

bool ViceEngineSetPauseEnabled(bool paused)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_pause(paused ? 1 : 0) != 0;
}

bool ViceEngineTriggerMachineReset(bool hardReset)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_machine_reset(hardReset ? 1U : 0U) != 0;
}

bool ViceEngineSetWarpMode(bool enabled)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_warp_mode(enabled ? 1 : 0) != 0;
}

bool ViceEngineResetDrive(uint32_t unit)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_drive_reset(unit) != 0;
}

bool ViceEngineAttachDisk(uint32_t unit, const char *path, bool autorun)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_drive_attach_disk(unit, 0, path, autorun ? 1 : 0) != 0;
}

bool ViceEngineAttachCartridge(const char *path)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_cartridge_attach(path) != 0;
}

bool ViceEngineDetachCartridge(void)
{
    if (!atomic_load(&engineRunning)) {
        return false;
    }

    return vicemac_queue_cartridge_detach() != 0;
}

static void *engineThreadMain(void *opaque)
{
    ViceEngineStartArguments *arguments = (ViceEngineStartArguments *)opaque;
    char sidModelArgument[12];
    char soundVolumeArgument[12];
    char speedArgument[12];
    char *argv[] = {
        arguments->executablePath,
        "-default",
        "-directory",
        arguments->dataDirectory,
        arguments->warpEnabled ? "-warp" : "+warp",
        "-speed",
        speedArgument,
        arguments->soundEnabled ? "-sound" : "+sound",
        "-sounddev",
        "coreaudio",
        "-soundrate",
        "48000",
        "-soundbufsize",
        "20",
        "-soundfragsize",
        "0",
        "-soundoutput",
        "0",
        "-soundwarpmode",
        "1",
        "-soundvolume",
        soundVolumeArgument,
        "-sidmodel",
        sidModelArgument,
        "-basic",
        arguments->basicROM,
        "-kernal",
        arguments->kernalROM,
        "-chargen",
        arguments->characterROM,
        NULL
    };
    int argc = (int)(sizeof(argv) / sizeof(argv[0])) - 1;

    snprintf(sidModelArgument, sizeof(sidModelArgument), "%d", (int)arguments->sidModel);
    snprintf(soundVolumeArgument, sizeof(soundVolumeArgument), "%d", (int)arguments->soundVolume);
    snprintf(speedArgument, sizeof(speedArgument), "%d", (int)arguments->speedPercent);

    archdep_program_path_set_argv0(arguments->executablePath);
    (void)main_program(argc, argv);

    atomic_store(&engineRunning, false);
    free(arguments->executablePath);
    free(arguments->dataDirectory);
    free(arguments->basicROM);
    free(arguments->kernalROM);
    free(arguments->characterROM);
    free(arguments);
    return NULL;
}

bool ViceEngineStartX64SC(const char *executablePath,
                          const char *dataDirectory,
                          int32_t sidModel,
                          bool soundEnabled,
                          int32_t soundVolume,
                          int32_t speedPercent,
                          bool warpEnabled,
                          const char *basicROM,
                          const char *kernalROM,
                          const char *characterROM)
{
    ViceEngineStartArguments *arguments;
    bool expected = false;

    if (executablePath == NULL
        || dataDirectory == NULL
        || basicROM == NULL
        || kernalROM == NULL
        || characterROM == NULL) {
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

    arguments->sidModel = sidModel;
    arguments->soundEnabled = soundEnabled;
    arguments->soundVolume = soundVolume;
    arguments->speedPercent = speedPercent <= 0 ? 100 : speedPercent;
    arguments->warpEnabled = warpEnabled;
    arguments->executablePath = strdup(executablePath);
    arguments->dataDirectory = strdup(dataDirectory);
    arguments->basicROM = strdup(basicROM);
    arguments->kernalROM = strdup(kernalROM);
    arguments->characterROM = strdup(characterROM);
    if (arguments->executablePath == NULL
        || arguments->dataDirectory == NULL
        || arguments->basicROM == NULL
        || arguments->kernalROM == NULL
        || arguments->characterROM == NULL) {
        free(arguments->executablePath);
        free(arguments->dataDirectory);
        free(arguments->basicROM);
        free(arguments->kernalROM);
        free(arguments->characterROM);
        free(arguments);
        atomic_store(&engineRunning, false);
        return false;
    }

    if (pthread_create(&engineThread, NULL, engineThreadMain, arguments) != 0) {
        free(arguments->executablePath);
        free(arguments->dataDirectory);
        free(arguments->basicROM);
        free(arguments->kernalROM);
        free(arguments->characterROM);
        free(arguments);
        atomic_store(&engineRunning, false);
        return false;
    }

    pthread_detach(engineThread);
    return true;
}
