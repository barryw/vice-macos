#include "ViceEngineBridge.h"

#include <dlfcn.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "vicemacbridge.h"

typedef int (*ViceMainProgramFunction)(int argc, char **argv);
typedef void (*ViceArchdepProgramPathSetArgv0Function)(char *argv0);
typedef void (*ViceSetVideoFrameCallbackFunction)(vicemac_video_frame_callback_t callback,
                                                  void *context);
typedef void (*ViceSetDriveStatusCallbackFunction)(vicemac_drive_status_callback_t callback,
                                                   void *context);
typedef void (*ViceSetCartridgeStatusCallbackFunction)(vicemac_cartridge_status_callback_t callback,
                                                       void *context);
typedef void (*ViceSetVSIDStateCallbackFunction)(vicemac_vsid_state_callback_t callback,
                                                 void *context);
typedef void (*ViceSetAudioSamplesCallbackFunction)(vicemac_audio_samples_callback_t callback,
                                                    void *context);
typedef void (*ViceSetSIDVoiceSamplesCallbackFunction)(vicemac_sid_voice_samples_callback_t callback,
                                                       void *context);
typedef const char *(*ViceGetVersionFunction)(void);
typedef int (*ViceQueueKeyEventFunction)(signed long key, int mod, int pressed);
typedef int (*ViceQueueKeyboardClearFunction)(void);
typedef int (*ViceQueueKeyboardTextFunction)(const char *text);
typedef int (*ViceQueueResourceIntFunction)(const char *name, int value);
typedef int (*ViceQueueResourceStringFunction)(const char *name, const char *value);
typedef int (*ViceQueueJoystickValueFunction)(uint32_t port, uint32_t value);
typedef int (*ViceQueueMouseMoveFunction)(float delta_x, float delta_y);
typedef int (*ViceQueueMouseButtonFunction)(uint32_t button, int pressed);
typedef int (*ViceQueueMouseResetFunction)(void);
typedef int (*ViceQueuePauseFunction)(int paused);
typedef int (*ViceQueueSystemTimeSyncFunction)(int enabled);
typedef int (*ViceQueueMachineModelFunction)(const char *model);
typedef int (*ViceQueueMachineResetFunction)(uint32_t reset_mode);
typedef int (*ViceQueueWarpModeFunction)(int enabled);
typedef int (*ViceQueueQuitFunction)(void);
typedef int (*ViceQueueDriveResetFunction)(uint32_t unit);
typedef int (*ViceQueueDriveAttachDiskFunction)(uint32_t unit,
                                                uint32_t drive,
                                                const char *path,
                                                int autorun);
typedef int (*ViceQueueDriveDetachDiskFunction)(uint32_t unit, uint32_t drive);
typedef int (*ViceQueueDriveSoundPreviewFunction)(uint32_t unit);
typedef int (*ViceQueueMediaAutostartFunction)(const char *path, int autorun);
typedef int (*ViceQueueCartridgeAttachFunction)(const char *path);
typedef int (*ViceQueueCartridgeDetachFunction)(void);
typedef int (*ViceSaveSnapshotFunction)(const char *path, int save_roms, int save_disks);
typedef int (*ViceLoadSnapshotFunction)(const char *path);
typedef int (*VicePeekMemoryFunction)(uint32_t memspace,
                                      int32_t bank,
                                      uint32_t address,
                                      uint8_t *buffer,
                                      uint32_t length);
typedef int (*VicePokeMemoryFunction)(uint32_t memspace,
                                      int32_t bank,
                                      uint32_t address,
                                      const uint8_t *bytes,
                                      uint32_t length);
typedef int (*ViceDebuggerSnapshotFunction)(uint32_t memspace,
                                            vicemac_debugger_snapshot_t *snapshot);
typedef int (*ViceDebuggerDisassembleFunction)(uint32_t memspace,
                                               int32_t bank,
                                               uint32_t address,
                                               vicemac_debugger_disassembly_line_t *lines,
                                               uint32_t capacity,
                                               uint32_t *count);
typedef int (*ViceDebuggerListCheckpointsFunction)(vicemac_debugger_checkpoint_t *checkpoints,
                                                   uint32_t capacity,
                                                   uint32_t *count);
typedef int (*ViceDebuggerSetCheckpointFunction)(uint32_t memspace,
                                                 uint32_t start_address,
                                                 uint32_t end_address,
                                                 uint32_t operations,
                                                 int stops,
                                                 int enabled,
                                                 int temporary,
                                                 uint32_t *checkpoint_id);
typedef int (*ViceDebuggerDeleteCheckpointFunction)(uint32_t checkpoint_id);
typedef int (*ViceDebuggerSetCheckpointEnabledFunction)(uint32_t checkpoint_id,
                                                       int enabled);
typedef int (*ViceDebuggerSetRegisterFunction)(uint32_t memspace,
                                               uint32_t register_id,
                                               uint32_t value);
typedef int (*ViceDebuggerSetCPUFunction)(uint32_t memspace, uint32_t cpu_type);
typedef int (*ViceDebuggerStepFunction)(uint32_t count, int step_over);
typedef int (*ViceDebuggerReturnFunction)(void);
typedef int (*ViceDebuggerContinueFunction)(void);

typedef struct ViceEngineSymbols {
    ViceMainProgramFunction mainProgram;
    ViceArchdepProgramPathSetArgv0Function archdepProgramPathSetArgv0;
    ViceSetVideoFrameCallbackFunction setVideoFrameCallback;
    ViceSetDriveStatusCallbackFunction setDriveStatusCallback;
    ViceSetCartridgeStatusCallbackFunction setCartridgeStatusCallback;
    ViceSetVSIDStateCallbackFunction setVSIDStateCallback;
    ViceSetAudioSamplesCallbackFunction setAudioSamplesCallback;
    ViceSetSIDVoiceSamplesCallbackFunction setSIDVoiceSamplesCallback;
    ViceGetVersionFunction getVersion;
    ViceQueueKeyEventFunction queueKeyEvent;
    ViceQueueKeyboardClearFunction queueKeyboardClear;
    ViceQueueKeyboardTextFunction queueKeyboardText;
    ViceQueueResourceIntFunction queueResourceInt;
    ViceQueueResourceStringFunction queueResourceString;
    ViceQueueJoystickValueFunction queueJoystickValue;
    ViceQueueMouseMoveFunction queueMouseMove;
    ViceQueueMouseButtonFunction queueMouseButton;
    ViceQueueMouseResetFunction queueMouseReset;
    ViceQueuePauseFunction queuePause;
    ViceQueueSystemTimeSyncFunction queueSystemTimeSync;
    ViceQueueMachineModelFunction queueMachineModel;
    ViceQueueMachineResetFunction queueMachineReset;
    ViceQueueWarpModeFunction queueWarpMode;
    ViceQueueQuitFunction queueQuit;
    ViceQueueDriveResetFunction queueDriveReset;
    ViceQueueDriveAttachDiskFunction queueDriveAttachDisk;
    ViceQueueDriveDetachDiskFunction queueDriveDetachDisk;
    ViceQueueDriveSoundPreviewFunction queueDriveSoundPreview;
    ViceQueueMediaAutostartFunction queueMediaAutostart;
    ViceQueueCartridgeAttachFunction queueCartridgeAttach;
    ViceQueueCartridgeDetachFunction queueCartridgeDetach;
    ViceSaveSnapshotFunction saveSnapshot;
    ViceLoadSnapshotFunction loadSnapshot;
    VicePeekMemoryFunction peekMemory;
    VicePokeMemoryFunction pokeMemory;
    ViceDebuggerSnapshotFunction debuggerSnapshot;
    ViceDebuggerDisassembleFunction debuggerDisassemble;
    ViceDebuggerListCheckpointsFunction debuggerListCheckpoints;
    ViceDebuggerSetCheckpointFunction debuggerSetCheckpoint;
    ViceDebuggerDeleteCheckpointFunction debuggerDeleteCheckpoint;
    ViceDebuggerSetCheckpointEnabledFunction debuggerSetCheckpointEnabled;
    ViceDebuggerSetRegisterFunction debuggerSetRegister;
    ViceDebuggerSetCPUFunction debuggerSetCPU;
    ViceDebuggerStepFunction debuggerStep;
    ViceDebuggerReturnFunction debuggerReturn;
    ViceDebuggerContinueFunction debuggerContinue;
} ViceEngineSymbols;

typedef struct ViceEngineStartArguments {
    char *machineID;
    int argc;
    char **argv;
} ViceEngineStartArguments;

static pthread_t engineThread;
static atomic_bool engineRunning = false;
static void *runtimeHandle = NULL;
static char *runtimePath = NULL;
static ViceEngineSymbols runtimeSymbols;
static pthread_mutex_t runtimeMutex = PTHREAD_MUTEX_INITIALIZER;
static char lastError[4096];

static ViceEngineVideoFrameCallback videoFrameCallback = NULL;
static void *videoFrameCallbackContext = NULL;
static ViceEngineDriveStatusCallback driveStatusCallback = NULL;
static void *driveStatusCallbackContext = NULL;
static ViceEngineCartridgeStatusCallback cartridgeStatusCallback = NULL;
static void *cartridgeStatusCallbackContext = NULL;
static ViceEngineVSIDStateCallback vsidStateCallback = NULL;
static void *vsidStateCallbackContext = NULL;
static ViceEngineAudioSamplesCallback audioSamplesCallback = NULL;
static void *audioSamplesCallbackContext = NULL;
static ViceEngineSIDVoiceSamplesCallback sidVoiceSamplesCallback = NULL;
static void *sidVoiceSamplesCallbackContext = NULL;

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
    bridgedStatus.activeDriveNumber = status->active_drive_number;
    bridgedStatus.ledColor = status->led_color;
    bridgedStatus.ledIntensity = status->led_pwm1;
    bridgedStatus.errorIntensity = status->led_pwm2;
    bridgedStatus.drive0LEDIntensity = status->drive0_led_intensity;
    bridgedStatus.drive1LEDIntensity = status->drive1_led_intensity;
    bridgedStatus.trackValid = status->track_valid != 0;
    bridgedStatus.track = status->track;
    bridgedStatus.halfTrack = status->half_track;
    bridgedStatus.diskSide = status->disk_side;
    bridgedStatus.driveStatusCode = status->drive_status_code;
    bridgedStatus.driveStatusText = status->drive_status_text;
    bridgedStatus.imagePath = status->image_path;
    bridgedStatus.drive0ImagePath = status->drive0_image_path;
    bridgedStatus.drive1ImagePath = status->drive1_image_path;

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

static void vsidStateTrampoline(const vicemac_vsid_state_t *state, void *context)
{
    ViceEngineVSIDState bridgedState;

    if (vsidStateCallback == NULL || state == NULL) {
        return;
    }

    memset(&bridgedState, 0, sizeof(bridgedState));
    snprintf(bridgedState.name, sizeof(bridgedState.name), "%s", state->name);
    snprintf(bridgedState.author, sizeof(bridgedState.author), "%s", state->author);
    snprintf(bridgedState.copyright, sizeof(bridgedState.copyright), "%s", state->copyright);
    snprintf(bridgedState.irq, sizeof(bridgedState.irq), "%s", state->irq);
    snprintf(bridgedState.driverInfo, sizeof(bridgedState.driverInfo), "%s", state->driver_info);
    bridgedState.sync = state->sync;
    bridgedState.sidModel = state->sid_model;
    bridgedState.currentTune = state->current_tune;
    bridgedState.tuneCount = state->tune_count;
    bridgedState.defaultTune = state->default_tune;
    bridgedState.deciseconds = state->deciseconds;
    bridgedState.driverAddress = state->driver_address;
    bridgedState.loadAddress = state->load_address;
    bridgedState.initAddress = state->init_address;
    bridgedState.playAddress = state->play_address;
    bridgedState.dataSize = state->data_size;

    vsidStateCallback(&bridgedState, context);
}

static void audioSamplesTrampoline(const vicemac_audio_samples_t *samples, void *context)
{
    ViceEngineAudioSamples bridgedSamples;

    if (audioSamplesCallback == NULL || samples == NULL) {
        return;
    }

    bridgedSamples.samples = samples->samples;
    bridgedSamples.frameCount = samples->frame_count;
    bridgedSamples.channelCount = samples->channel_count;
    bridgedSamples.sampleRate = samples->sample_rate;
    bridgedSamples.sequence = samples->sequence;

    audioSamplesCallback(&bridgedSamples, context);
}

static void sidVoiceSamplesTrampoline(const vicemac_sid_voice_samples_t *samples, void *context)
{
    ViceEngineSIDVoiceSamples bridgedSamples;

    if (sidVoiceSamplesCallback == NULL || samples == NULL) {
        return;
    }

    memset(&bridgedSamples, 0, sizeof(bridgedSamples));
    bridgedSamples.samples = samples->samples;
    bridgedSamples.frameCount = samples->frame_count;
    bridgedSamples.voiceCount = samples->voice_count;
    bridgedSamples.chipIndex = samples->chip_index;
    bridgedSamples.sampleRate = samples->sample_rate;
    bridgedSamples.clockRate = samples->clock_rate;
    for (uint32_t voice = 0; voice < VICE_ENGINE_SID_VOICE_COUNT; voice++) {
        bridgedSamples.frequency[voice] = samples->frequency[voice];
        bridgedSamples.control[voice] = samples->control[voice];
    }
    bridgedSamples.sequence = samples->sequence;

    sidVoiceSamplesCallback(&bridgedSamples, context);
}

static void clearLastError(void)
{
    lastError[0] = '\0';
}

static void setAndPrintLastError(const char *format, ...)
{
    char message[sizeof(lastError)];
    va_list arguments;

    va_start(arguments, format);
    vsnprintf(message, sizeof(message), format, arguments);
    va_end(arguments);

    pthread_mutex_lock(&runtimeMutex);
    snprintf(lastError, sizeof(lastError), "%s", message);
    pthread_mutex_unlock(&runtimeMutex);

    if (message[0] != '\0') {
        fprintf(stderr, "%s\n", message);
    }
}

static void setAndPrintLastErrorLocked(const char *format, ...)
{
    va_list arguments;

    va_start(arguments, format);
    vsnprintf(lastError, sizeof(lastError), format, arguments);
    va_end(arguments);

    if (lastError[0] != '\0') {
        fprintf(stderr, "%s\n", lastError);
    }
}

static int loadRuntimeSymbols(void *handle, ViceEngineSymbols *symbols)
{
#define LOAD_RUNTIME_SYMBOL(field, symbolName) \
    do { \
        symbols->field = (typeof(symbols->field))dlsym(handle, symbolName); \
        if (symbols->field == NULL) { \
            setAndPrintLastErrorLocked("VICE Mac: missing runtime symbol %s", symbolName); \
            return 0; \
        } \
    } while (0)

    memset(symbols, 0, sizeof(*symbols));
    LOAD_RUNTIME_SYMBOL(mainProgram, "main_program");
    LOAD_RUNTIME_SYMBOL(archdepProgramPathSetArgv0, "archdep_program_path_set_argv0");
    LOAD_RUNTIME_SYMBOL(setVideoFrameCallback, "vicemac_set_video_frame_callback");
    LOAD_RUNTIME_SYMBOL(setDriveStatusCallback, "vicemac_set_drive_status_callback");
    LOAD_RUNTIME_SYMBOL(setCartridgeStatusCallback, "vicemac_set_cartridge_status_callback");
    LOAD_RUNTIME_SYMBOL(setVSIDStateCallback, "vicemac_set_vsid_state_callback");
    LOAD_RUNTIME_SYMBOL(setAudioSamplesCallback, "vicemac_set_audio_samples_callback");
    LOAD_RUNTIME_SYMBOL(setSIDVoiceSamplesCallback, "vicemac_set_sid_voice_samples_callback");
    LOAD_RUNTIME_SYMBOL(getVersion, "vicemac_get_vice_version");
    LOAD_RUNTIME_SYMBOL(queueKeyEvent, "vicemac_queue_key_event");
    LOAD_RUNTIME_SYMBOL(queueKeyboardClear, "vicemac_queue_keyboard_clear");
    LOAD_RUNTIME_SYMBOL(queueKeyboardText, "vicemac_queue_keyboard_text");
    LOAD_RUNTIME_SYMBOL(queueResourceInt, "vicemac_queue_resource_int");
    LOAD_RUNTIME_SYMBOL(queueResourceString, "vicemac_queue_resource_string");
    LOAD_RUNTIME_SYMBOL(queueJoystickValue, "vicemac_queue_joystick_value");
    LOAD_RUNTIME_SYMBOL(queueMouseMove, "vicemac_queue_mouse_move");
    LOAD_RUNTIME_SYMBOL(queueMouseButton, "vicemac_queue_mouse_button");
    LOAD_RUNTIME_SYMBOL(queueMouseReset, "vicemac_queue_mouse_reset");
    LOAD_RUNTIME_SYMBOL(queuePause, "vicemac_queue_pause");
    LOAD_RUNTIME_SYMBOL(queueSystemTimeSync, "vicemac_queue_system_time_sync");
    LOAD_RUNTIME_SYMBOL(queueMachineModel, "vicemac_queue_machine_model");
    LOAD_RUNTIME_SYMBOL(queueMachineReset, "vicemac_queue_machine_reset");
    LOAD_RUNTIME_SYMBOL(queueWarpMode, "vicemac_queue_warp_mode");
    LOAD_RUNTIME_SYMBOL(queueQuit, "vicemac_queue_quit");
    LOAD_RUNTIME_SYMBOL(queueDriveReset, "vicemac_queue_drive_reset");
    LOAD_RUNTIME_SYMBOL(queueDriveAttachDisk, "vicemac_queue_drive_attach_disk");
    LOAD_RUNTIME_SYMBOL(queueDriveDetachDisk, "vicemac_queue_drive_detach_disk");
    LOAD_RUNTIME_SYMBOL(queueDriveSoundPreview, "vicemac_queue_drive_sound_preview");
    LOAD_RUNTIME_SYMBOL(queueMediaAutostart, "vicemac_queue_media_autostart");
    LOAD_RUNTIME_SYMBOL(queueCartridgeAttach, "vicemac_queue_cartridge_attach");
    LOAD_RUNTIME_SYMBOL(queueCartridgeDetach, "vicemac_queue_cartridge_detach");
    LOAD_RUNTIME_SYMBOL(saveSnapshot, "vicemac_save_snapshot");
    LOAD_RUNTIME_SYMBOL(loadSnapshot, "vicemac_load_snapshot");
    LOAD_RUNTIME_SYMBOL(peekMemory, "vicemac_peek_memory");
    LOAD_RUNTIME_SYMBOL(pokeMemory, "vicemac_poke_memory");
    LOAD_RUNTIME_SYMBOL(debuggerSnapshot, "vicemac_debugger_snapshot");
    LOAD_RUNTIME_SYMBOL(debuggerDisassemble, "vicemac_debugger_disassemble");
    LOAD_RUNTIME_SYMBOL(debuggerListCheckpoints, "vicemac_debugger_list_checkpoints");
    LOAD_RUNTIME_SYMBOL(debuggerSetCheckpoint, "vicemac_debugger_set_checkpoint");
    LOAD_RUNTIME_SYMBOL(debuggerDeleteCheckpoint, "vicemac_debugger_delete_checkpoint");
    LOAD_RUNTIME_SYMBOL(debuggerSetCheckpointEnabled, "vicemac_debugger_set_checkpoint_enabled");
    LOAD_RUNTIME_SYMBOL(debuggerSetRegister, "vicemac_debugger_set_register");
    LOAD_RUNTIME_SYMBOL(debuggerSetCPU, "vicemac_debugger_set_cpu");
    LOAD_RUNTIME_SYMBOL(debuggerStep, "vicemac_debugger_step");
    LOAD_RUNTIME_SYMBOL(debuggerReturn, "vicemac_debugger_return");
    LOAD_RUNTIME_SYMBOL(debuggerContinue, "vicemac_debugger_continue");

#undef LOAD_RUNTIME_SYMBOL
    return 1;
}

static void applyStoredCallbacks(void)
{
    if (runtimeHandle == NULL) {
        return;
    }

    runtimeSymbols.setVideoFrameCallback(videoFrameTrampoline,
                                         videoFrameCallbackContext);
    runtimeSymbols.setDriveStatusCallback(driveStatusTrampoline,
                                          driveStatusCallbackContext);
    runtimeSymbols.setCartridgeStatusCallback(cartridgeStatusTrampoline,
                                              cartridgeStatusCallbackContext);
    runtimeSymbols.setVSIDStateCallback(vsidStateTrampoline,
                                        vsidStateCallbackContext);
    runtimeSymbols.setAudioSamplesCallback(audioSamplesTrampoline,
                                           audioSamplesCallbackContext);
    runtimeSymbols.setSIDVoiceSamplesCallback(sidVoiceSamplesTrampoline,
                                              sidVoiceSamplesCallbackContext);
}

static int ensureRuntimeLoaded(const char *dynamicLibraryPath)
{
    void *handle;
    ViceEngineSymbols symbols;

    if (dynamicLibraryPath == NULL || dynamicLibraryPath[0] == '\0') {
        setAndPrintLastError("VICE Mac: dynamic library path is missing");
        return 0;
    }

    pthread_mutex_lock(&runtimeMutex);

    if (runtimeHandle != NULL) {
        int matches = runtimePath != NULL && strcmp(runtimePath, dynamicLibraryPath) == 0;
        if (!matches) {
            setAndPrintLastErrorLocked("VICE Mac: runtime already loaded from %s; cannot load %s",
                                       runtimePath == NULL ? "<unknown>" : runtimePath,
                                       dynamicLibraryPath);
        }
        pthread_mutex_unlock(&runtimeMutex);
        return matches;
    }

    handle = dlopen(dynamicLibraryPath, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        setAndPrintLastErrorLocked("VICE Mac: unable to load %s: %s",
                                   dynamicLibraryPath,
                                   dlerror());
        pthread_mutex_unlock(&runtimeMutex);
        return 0;
    }

    if (!loadRuntimeSymbols(handle, &symbols)) {
        dlclose(handle);
        pthread_mutex_unlock(&runtimeMutex);
        return 0;
    }

    runtimePath = strdup(dynamicLibraryPath);
    if (runtimePath == NULL) {
        setAndPrintLastErrorLocked("VICE Mac: unable to store runtime path");
        dlclose(handle);
        pthread_mutex_unlock(&runtimeMutex);
        return 0;
    }

    runtimeSymbols = symbols;
    runtimeHandle = handle;
    applyStoredCallbacks();

    pthread_mutex_unlock(&runtimeMutex);
    return 1;
}

void ViceEngineSetVideoFrameCallback(ViceEngineVideoFrameCallback callback,
                                     void *context)
{
    pthread_mutex_lock(&runtimeMutex);
    videoFrameCallback = callback;
    videoFrameCallbackContext = context;
    if (runtimeHandle != NULL) {
        runtimeSymbols.setVideoFrameCallback(videoFrameTrampoline, context);
    }
    pthread_mutex_unlock(&runtimeMutex);
}

void ViceEngineSetDriveStatusCallback(ViceEngineDriveStatusCallback callback,
                                      void *context)
{
    pthread_mutex_lock(&runtimeMutex);
    driveStatusCallback = callback;
    driveStatusCallbackContext = context;
    if (runtimeHandle != NULL) {
        runtimeSymbols.setDriveStatusCallback(driveStatusTrampoline, context);
    }
    pthread_mutex_unlock(&runtimeMutex);
}

void ViceEngineSetCartridgeStatusCallback(ViceEngineCartridgeStatusCallback callback,
                                          void *context)
{
    pthread_mutex_lock(&runtimeMutex);
    cartridgeStatusCallback = callback;
    cartridgeStatusCallbackContext = context;
    if (runtimeHandle != NULL) {
        runtimeSymbols.setCartridgeStatusCallback(cartridgeStatusTrampoline, context);
    }
    pthread_mutex_unlock(&runtimeMutex);
}

void ViceEngineSetVSIDStateCallback(ViceEngineVSIDStateCallback callback,
                                    void *context)
{
    pthread_mutex_lock(&runtimeMutex);
    vsidStateCallback = callback;
    vsidStateCallbackContext = context;
    if (runtimeHandle != NULL) {
        runtimeSymbols.setVSIDStateCallback(vsidStateTrampoline, context);
    }
    pthread_mutex_unlock(&runtimeMutex);
}

void ViceEngineSetAudioSamplesCallback(ViceEngineAudioSamplesCallback callback,
                                       void *context)
{
    pthread_mutex_lock(&runtimeMutex);
    audioSamplesCallback = callback;
    audioSamplesCallbackContext = context;
    if (runtimeHandle != NULL) {
        runtimeSymbols.setAudioSamplesCallback(audioSamplesTrampoline, context);
    }
    pthread_mutex_unlock(&runtimeMutex);
}

void ViceEngineSetSIDVoiceSamplesCallback(ViceEngineSIDVoiceSamplesCallback callback,
                                          void *context)
{
    pthread_mutex_lock(&runtimeMutex);
    sidVoiceSamplesCallback = callback;
    sidVoiceSamplesCallbackContext = context;
    if (runtimeHandle != NULL) {
        runtimeSymbols.setSIDVoiceSamplesCallback(sidVoiceSamplesTrampoline, context);
    }
    pthread_mutex_unlock(&runtimeMutex);
}

const char *ViceEngineGetVersion(void)
{
    const char *version = NULL;

    pthread_mutex_lock(&runtimeMutex);
    if (runtimeHandle != NULL && runtimeSymbols.getVersion != NULL) {
        version = runtimeSymbols.getVersion();
    }
    pthread_mutex_unlock(&runtimeMutex);

    return version;
}

const char *ViceEngineGetLastError(void)
{
    const char *error = NULL;

    pthread_mutex_lock(&runtimeMutex);
    if (lastError[0] != '\0') {
        error = lastError;
    }
    pthread_mutex_unlock(&runtimeMutex);

    return error;
}

bool ViceEngineIsRunning(void)
{
    return atomic_load(&engineRunning);
}

bool ViceEngineRequestQuit(void)
{
    bool queued = false;

    if (!atomic_load(&engineRunning)) {
        return true;
    }

    pthread_mutex_lock(&runtimeMutex);
    if (runtimeHandle != NULL && runtimeSymbols.queueQuit != NULL) {
        runtimeSymbols.setVideoFrameCallback(NULL, NULL);
        runtimeSymbols.setDriveStatusCallback(NULL, NULL);
        runtimeSymbols.setCartridgeStatusCallback(NULL, NULL);
        runtimeSymbols.setVSIDStateCallback(NULL, NULL);
        runtimeSymbols.setAudioSamplesCallback(NULL, NULL);
        runtimeSymbols.setSIDVoiceSamplesCallback(NULL, NULL);

        videoFrameCallback = NULL;
        videoFrameCallbackContext = NULL;
        driveStatusCallback = NULL;
        driveStatusCallbackContext = NULL;
        cartridgeStatusCallback = NULL;
        cartridgeStatusCallbackContext = NULL;
        vsidStateCallback = NULL;
        vsidStateCallbackContext = NULL;
        audioSamplesCallback = NULL;
        audioSamplesCallbackContext = NULL;
        sidVoiceSamplesCallback = NULL;
        sidVoiceSamplesCallbackContext = NULL;

        queued = runtimeSymbols.queueQuit() != 0;
    }
    pthread_mutex_unlock(&runtimeMutex);

    return queued;
}

void ViceEngineSendKeyEvent(int64_t key, int32_t modifiers, bool pressed)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueKeyEvent == NULL) {
        return;
    }

    (void)runtimeSymbols.queueKeyEvent((signed long)key, (int)modifiers, pressed ? 1 : 0);
}

void ViceEngineReleaseAllKeys(void)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueKeyboardClear == NULL) {
        return;
    }

    (void)runtimeSymbols.queueKeyboardClear();
}

bool ViceEngineFeedKeyboardText(const char *text)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueKeyboardText == NULL) {
        return false;
    }

    return runtimeSymbols.queueKeyboardText(text) != 0;
}

bool ViceEngineSetIntResource(const char *name, int32_t value)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueResourceInt == NULL) {
        return false;
    }

    return runtimeSymbols.queueResourceInt(name, (int)value) != 0;
}

bool ViceEngineSetStringResource(const char *name, const char *value)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueResourceString == NULL) {
        return false;
    }

    return runtimeSymbols.queueResourceString(name, value) != 0;
}

bool ViceEngineSetJoystickValue(uint32_t port, uint32_t value)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueJoystickValue == NULL) {
        return false;
    }

    return runtimeSymbols.queueJoystickValue(port, value) != 0;
}

bool ViceEngineMoveMouse(float deltaX, float deltaY)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueMouseMove == NULL) {
        return false;
    }

    return runtimeSymbols.queueMouseMove(deltaX, deltaY) != 0;
}

bool ViceEngineSetMouseButton(uint32_t button, bool pressed)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueMouseButton == NULL) {
        return false;
    }

    return runtimeSymbols.queueMouseButton(button, pressed ? 1 : 0) != 0;
}

bool ViceEngineResetMouse(void)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueMouseReset == NULL) {
        return false;
    }

    return runtimeSymbols.queueMouseReset() != 0;
}

bool ViceEngineSetPauseEnabled(bool paused)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queuePause == NULL) {
        return false;
    }

    return runtimeSymbols.queuePause(paused ? 1 : 0) != 0;
}

bool ViceEngineSetSystemTimeSyncEnabled(bool enabled)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueSystemTimeSync == NULL) {
        return false;
    }

    return runtimeSymbols.queueSystemTimeSync(enabled ? 1 : 0) != 0;
}

bool ViceEngineSetMachineModel(const char *model)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueMachineModel == NULL) {
        return false;
    }

    return runtimeSymbols.queueMachineModel(model) != 0;
}

bool ViceEngineTriggerMachineReset(bool hardReset)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueMachineReset == NULL) {
        return false;
    }

    return runtimeSymbols.queueMachineReset(hardReset ? 1U : 0U) != 0;
}

bool ViceEngineSetWarpMode(bool enabled)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueWarpMode == NULL) {
        return false;
    }

    return runtimeSymbols.queueWarpMode(enabled ? 1 : 0) != 0;
}

bool ViceEngineResetDrive(uint32_t unit)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueDriveReset == NULL) {
        return false;
    }

    return runtimeSymbols.queueDriveReset(unit) != 0;
}

bool ViceEngineAttachDisk(uint32_t unit, uint32_t drive, const char *path, bool autorun)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueDriveAttachDisk == NULL) {
        return false;
    }

    return runtimeSymbols.queueDriveAttachDisk(unit, drive, path, autorun ? 1 : 0) != 0;
}

bool ViceEngineDetachDisk(uint32_t unit, uint32_t drive)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueDriveDetachDisk == NULL) {
        return false;
    }

    return runtimeSymbols.queueDriveDetachDisk(unit, drive) != 0;
}

bool ViceEnginePreviewDriveSound(uint32_t unit)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueDriveSoundPreview == NULL) {
        return false;
    }

    return runtimeSymbols.queueDriveSoundPreview(unit) != 0;
}

bool ViceEngineAutostartMedia(const char *path, bool autorun)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueMediaAutostart == NULL) {
        return false;
    }

    return runtimeSymbols.queueMediaAutostart(path, autorun ? 1 : 0) != 0;
}

bool ViceEngineAttachCartridge(const char *path)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueCartridgeAttach == NULL) {
        return false;
    }

    return runtimeSymbols.queueCartridgeAttach(path) != 0;
}

bool ViceEngineDetachCartridge(void)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.queueCartridgeDetach == NULL) {
        return false;
    }

    return runtimeSymbols.queueCartridgeDetach() != 0;
}

bool ViceEngineSaveSnapshot(const char *path, bool saveROMs, bool saveDisks)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.saveSnapshot == NULL) {
        return false;
    }

    return runtimeSymbols.saveSnapshot(path, saveROMs ? 1 : 0, saveDisks ? 1 : 0) != 0;
}

bool ViceEngineLoadSnapshot(const char *path)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.loadSnapshot == NULL) {
        return false;
    }

    return runtimeSymbols.loadSnapshot(path) != 0;
}

bool ViceEnginePeekMemory(uint32_t memorySpace,
                          int32_t bank,
                          uint32_t address,
                          uint8_t *buffer,
                          uint32_t length)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.peekMemory == NULL) {
        return false;
    }

    return runtimeSymbols.peekMemory(memorySpace, bank, address, buffer, length) != 0;
}

bool ViceEnginePokeMemory(uint32_t memorySpace,
                          int32_t bank,
                          uint32_t address,
                          const uint8_t *bytes,
                          uint32_t length)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.pokeMemory == NULL) {
        return false;
    }

    return runtimeSymbols.pokeMemory(memorySpace, bank, address, bytes, length) != 0;
}

bool ViceEngineDebuggerCaptureSnapshot(uint32_t memorySpace,
                                       ViceEngineDebuggerSnapshot *snapshot)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerSnapshot == NULL || snapshot == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerSnapshot(memorySpace,
                                           (vicemac_debugger_snapshot_t *)snapshot) != 0;
}

bool ViceEngineDebuggerDisassemble(uint32_t memorySpace,
                                   int32_t bank,
                                   uint32_t address,
                                   ViceEngineDebuggerDisassemblyLine *lines,
                                   uint32_t capacity,
                                   uint32_t *count)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerDisassemble == NULL
        || lines == NULL || count == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerDisassemble(memorySpace,
                                              bank,
                                              address,
                                              (vicemac_debugger_disassembly_line_t *)lines,
                                              capacity,
                                              count) != 0;
}

bool ViceEngineDebuggerListCheckpoints(ViceEngineDebuggerCheckpoint *checkpoints,
                                       uint32_t capacity,
                                       uint32_t *count)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerListCheckpoints == NULL
        || checkpoints == NULL || count == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerListCheckpoints((vicemac_debugger_checkpoint_t *)checkpoints,
                                                  capacity,
                                                  count) != 0;
}

bool ViceEngineDebuggerSetCheckpoint(uint32_t memorySpace,
                                     uint32_t startAddress,
                                     uint32_t endAddress,
                                     uint32_t operations,
                                     bool stops,
                                     bool enabled,
                                     bool temporary,
                                     uint32_t *checkpointID)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerSetCheckpoint == NULL
        || checkpointID == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerSetCheckpoint(memorySpace,
                                                startAddress,
                                                endAddress,
                                                operations,
                                                stops ? 1 : 0,
                                                enabled ? 1 : 0,
                                                temporary ? 1 : 0,
                                                checkpointID) != 0;
}

bool ViceEngineDebuggerDeleteCheckpoint(uint32_t checkpointID)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerDeleteCheckpoint == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerDeleteCheckpoint(checkpointID) != 0;
}

bool ViceEngineDebuggerSetCheckpointEnabled(uint32_t checkpointID, bool enabled)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerSetCheckpointEnabled == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerSetCheckpointEnabled(checkpointID, enabled ? 1 : 0) != 0;
}

bool ViceEngineDebuggerSetRegister(uint32_t memorySpace,
                                   uint32_t registerID,
                                   uint32_t value)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerSetRegister == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerSetRegister(memorySpace, registerID, value) != 0;
}

bool ViceEngineDebuggerSetCPU(uint32_t memorySpace, uint32_t cpuType)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerSetCPU == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerSetCPU(memorySpace, cpuType) != 0;
}

bool ViceEngineDebuggerStep(uint32_t count, bool stepOver)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerStep == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerStep(count, stepOver ? 1 : 0) != 0;
}

bool ViceEngineDebuggerReturn(void)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerReturn == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerReturn() != 0;
}

bool ViceEngineDebuggerContinue(void)
{
    if (!atomic_load(&engineRunning) || runtimeSymbols.debuggerContinue == NULL) {
        return false;
    }

    return runtimeSymbols.debuggerContinue() != 0;
}

static void freeStartArguments(ViceEngineStartArguments *arguments)
{
    int index;

    if (arguments == NULL) {
        return;
    }

    free(arguments->machineID);
    if (arguments->argv != NULL) {
        for (index = 0; index < arguments->argc; index++) {
            free(arguments->argv[index]);
        }
        free(arguments->argv);
    }
    free(arguments);
}

static ViceEngineStartArguments *copyStartArguments(const char *machineID,
                                                    int32_t argc,
                                                    const char * const *argv)
{
    ViceEngineStartArguments *arguments;
    int index;

    if (machineID == NULL || machineID[0] == '\0' || argc <= 0 || argv == NULL) {
        return NULL;
    }

    arguments = (ViceEngineStartArguments *)calloc(1, sizeof(*arguments));
    if (arguments == NULL) {
        return NULL;
    }

    arguments->machineID = strdup(machineID);
    arguments->argc = (int)argc;
    arguments->argv = (char **)calloc((size_t)argc + 1, sizeof(char *));
    if (arguments->machineID == NULL || arguments->argv == NULL) {
        freeStartArguments(arguments);
        return NULL;
    }

    for (index = 0; index < argc; index++) {
        if (argv[index] == NULL) {
            freeStartArguments(arguments);
            return NULL;
        }

        arguments->argv[index] = strdup(argv[index]);
        if (arguments->argv[index] == NULL) {
            freeStartArguments(arguments);
            return NULL;
        }
    }
    arguments->argv[argc] = NULL;

    return arguments;
}

static void *engineThreadMain(void *opaque)
{
    ViceEngineStartArguments *arguments = (ViceEngineStartArguments *)opaque;

    runtimeSymbols.archdepProgramPathSetArgv0(arguments->argv[0]);
    (void)runtimeSymbols.mainProgram(arguments->argc, arguments->argv);

    atomic_store(&engineRunning, false);
    freeStartArguments(arguments);
    return NULL;
}

bool ViceEngineStartMachine(const char *machineID,
                            const char *dynamicLibraryPath,
                            int32_t argc,
                            const char * const *argv)
{
    ViceEngineStartArguments *arguments;
    bool expected = false;

    pthread_mutex_lock(&runtimeMutex);
    clearLastError();
    pthread_mutex_unlock(&runtimeMutex);

    if (!ensureRuntimeLoaded(dynamicLibraryPath)) {
        return false;
    }

    if (!atomic_compare_exchange_strong(&engineRunning, &expected, true)) {
        setAndPrintLastError("VICE Mac: emulator engine is already running");
        return false;
    }

    arguments = copyStartArguments(machineID, argc, argv);
    if (arguments == NULL) {
        setAndPrintLastError("VICE Mac: unable to copy startup arguments");
        atomic_store(&engineRunning, false);
        return false;
    }

    if (pthread_create(&engineThread, NULL, engineThreadMain, arguments) != 0) {
        setAndPrintLastError("VICE Mac: unable to create emulator thread");
        freeStartArguments(arguments);
        atomic_store(&engineRunning, false);
        return false;
    }

    pthread_detach(engineThread);
    return true;
}
