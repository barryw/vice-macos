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

typedef struct ViceEngineDriveStatus {
    uint32_t unit;
    bool enabled;
    int32_t driveType;
    uint32_t activeDriveNumber;
    uint32_t ledColor;
    uint32_t ledIntensity;
    uint32_t errorIntensity;
    uint32_t drive0LEDIntensity;
    uint32_t drive1LEDIntensity;
    bool trackValid;
    uint32_t track;
    uint32_t halfTrack;
    uint32_t diskSide;
    int32_t driveStatusCode;
    const char *driveStatusText;
    const char *imagePath;
    const char *drive0ImagePath;
    const char *drive1ImagePath;
} ViceEngineDriveStatus;

typedef struct ViceEngineCartridgeStatus {
    bool attached;
    int32_t cartridgeID;
    uint32_t cartridgeFlags;
    uint32_t romSize;
    uint32_t chipCount;
    uint32_t bankCount;
    const char *cartridgeName;
    const char *imagePath;
} ViceEngineCartridgeStatus;

#define VICE_ENGINE_VSID_TEXT_CAPACITY 192U

typedef struct ViceEngineVSIDState {
    char name[VICE_ENGINE_VSID_TEXT_CAPACITY];
    char author[VICE_ENGINE_VSID_TEXT_CAPACITY];
    char copyright[VICE_ENGINE_VSID_TEXT_CAPACITY];
    char irq[VICE_ENGINE_VSID_TEXT_CAPACITY];
    char driverInfo[VICE_ENGINE_VSID_TEXT_CAPACITY];
    uint32_t sync;
    int32_t sidModel;
    uint32_t currentTune;
    uint32_t tuneCount;
    uint32_t defaultTune;
    uint32_t deciseconds;
    uint32_t driverAddress;
    uint32_t loadAddress;
    uint32_t initAddress;
    uint32_t playAddress;
    uint32_t dataSize;
} ViceEngineVSIDState;

typedef struct ViceEngineAudioSamples {
    const int16_t *samples;
    uint32_t frameCount;
    uint32_t channelCount;
    uint32_t sampleRate;
    uint64_t sequence;
} ViceEngineAudioSamples;

#define VICE_ENGINE_SID_VOICE_COUNT 3U

typedef struct ViceEngineSIDVoiceSamples {
    const int16_t *samples;
    uint32_t frameCount;
    uint32_t voiceCount;
    uint32_t chipIndex;
    uint32_t sampleRate;
    uint32_t clockRate;
    uint16_t frequency[VICE_ENGINE_SID_VOICE_COUNT];
    uint8_t control[VICE_ENGINE_SID_VOICE_COUNT];
    uint64_t sequence;
} ViceEngineSIDVoiceSamples;

#define VICE_ENGINE_DEBUGGER_MAX_REGISTERS 96U
#define VICE_ENGINE_DEBUGGER_MAX_CPUS 8U
#define VICE_ENGINE_DEBUGGER_REGISTER_NAME_CAPACITY 16U
#define VICE_ENGINE_DEBUGGER_DISASSEMBLY_TEXT_CAPACITY 96U

typedef struct ViceEngineDebuggerRegister {
    uint32_t id;
    uint32_t bitWidth;
    uint32_t flags;
    uint32_t extra;
    uint32_t value;
    char name[VICE_ENGINE_DEBUGGER_REGISTER_NAME_CAPACITY];
} ViceEngineDebuggerRegister;

typedef struct ViceEngineDebuggerSnapshot {
    uint32_t valid;
    uint32_t memorySpace;
    uint32_t cpuType;
    int32_t bank;
    uint64_t cycle;
    uint32_t programCounter;
    uint32_t supportedCPUCount;
    uint32_t supportedCPUTypes[VICE_ENGINE_DEBUGGER_MAX_CPUS];
    uint32_t registerCount;
    ViceEngineDebuggerRegister registers[VICE_ENGINE_DEBUGGER_MAX_REGISTERS];
} ViceEngineDebuggerSnapshot;

typedef struct ViceEngineDebuggerDisassemblyLine {
    uint32_t address;
    uint32_t size;
    uint8_t bytes[4];
    char text[VICE_ENGINE_DEBUGGER_DISASSEMBLY_TEXT_CAPACITY];
} ViceEngineDebuggerDisassemblyLine;

typedef struct ViceEngineDebuggerCheckpoint {
    uint32_t id;
    uint32_t memorySpace;
    uint32_t startAddress;
    uint32_t endAddress;
    uint32_t operations;
    uint32_t enabled;
    uint32_t stops;
    uint32_t temporary;
    uint32_t hitCount;
    uint32_t ignoreCount;
} ViceEngineDebuggerCheckpoint;

typedef void (*ViceEngineVideoFrameCallback)(const ViceEngineVideoFrame *frame,
                                             void *context);
typedef void (*ViceEngineDriveStatusCallback)(const ViceEngineDriveStatus *status,
                                              void *context);
typedef void (*ViceEngineCartridgeStatusCallback)(const ViceEngineCartridgeStatus *status,
                                                  void *context);
typedef void (*ViceEngineVSIDStateCallback)(const ViceEngineVSIDState *state,
                                            void *context);
typedef void (*ViceEngineAudioSamplesCallback)(const ViceEngineAudioSamples *samples,
                                               void *context);
typedef void (*ViceEngineSIDVoiceSamplesCallback)(const ViceEngineSIDVoiceSamples *samples,
                                                 void *context);

void ViceEngineSetVideoFrameCallback(ViceEngineVideoFrameCallback callback,
                                     void *context);
void ViceEngineSetDriveStatusCallback(ViceEngineDriveStatusCallback callback,
                                      void *context);
void ViceEngineSetCartridgeStatusCallback(ViceEngineCartridgeStatusCallback callback,
                                          void *context);
void ViceEngineSetVSIDStateCallback(ViceEngineVSIDStateCallback callback,
                                    void *context);
void ViceEngineSetAudioSamplesCallback(ViceEngineAudioSamplesCallback callback,
                                       void *context);
void ViceEngineSetSIDVoiceSamplesCallback(ViceEngineSIDVoiceSamplesCallback callback,
                                          void *context);
const char *ViceEngineGetVersion(void);
const char *ViceEngineGetLastError(void);
bool ViceEngineStartMachine(const char *machineID,
                            const char *dynamicLibraryPath,
                            int32_t argc,
                            const char * const *argv);
bool ViceEngineIsRunning(void);
bool ViceEngineRequestQuit(void);
void ViceEngineSendKeyEvent(int64_t key, int32_t modifiers, bool pressed);
void ViceEngineReleaseAllKeys(void);
bool ViceEngineFeedKeyboardText(const char *text);
bool ViceEngineSetIntResource(const char *name, int32_t value);
bool ViceEngineSetStringResource(const char *name, const char *value);
bool ViceEngineGetIntResource(const char *name, int32_t *value);
bool ViceEngineGetStringResource(const char *name, char *buffer, uint32_t bufferCapacity);
bool ViceEngineSetJoystickValue(uint32_t port, uint32_t value);
bool ViceEngineMoveMouse(float deltaX, float deltaY);
bool ViceEngineSetMouseButton(uint32_t button, bool pressed);
bool ViceEngineResetMouse(void);
bool ViceEngineSetPauseEnabled(bool paused);
bool ViceEngineSetSystemTimeSyncEnabled(bool enabled);
bool ViceEngineSetMachineModel(const char *model);
bool ViceEngineTriggerMachineReset(bool hardReset);
bool ViceEngineSetWarpMode(bool enabled);
bool ViceEngineResetDrive(uint32_t unit);
bool ViceEngineAttachDisk(uint32_t unit,
                          uint32_t drive,
                          const char *path,
                          const char *programName,
                          int32_t runMode);
bool ViceEngineDetachDisk(uint32_t unit, uint32_t drive);
bool ViceEnginePreviewDriveSound(uint32_t unit);
bool ViceEngineAutostartMedia(const char *path, int32_t runMode);
bool ViceEngineAttachTape(uint32_t unit, const char *path);
bool ViceEngineDetachTape(uint32_t unit);
bool ViceEngineControlTape(uint32_t unit, int32_t command);
bool ViceEngineAttachCartridge(const char *path);
bool ViceEngineDetachCartridge(void);
bool ViceEngineSaveSnapshot(const char *path, bool saveROMs, bool saveDisks);
bool ViceEngineLoadSnapshot(const char *path);
bool ViceEnginePeekMemory(uint32_t memorySpace,
                          int32_t bank,
                          uint32_t address,
                          uint8_t *buffer,
                          uint32_t length);
bool ViceEnginePokeMemory(uint32_t memorySpace,
                          int32_t bank,
                          uint32_t address,
                          const uint8_t *bytes,
                          uint32_t length);
bool ViceEngineDebuggerCaptureSnapshot(uint32_t memorySpace,
                                       ViceEngineDebuggerSnapshot *snapshot);
bool ViceEngineDebuggerDisassemble(uint32_t memorySpace,
                                   int32_t bank,
                                   uint32_t address,
                                   ViceEngineDebuggerDisassemblyLine *lines,
                                   uint32_t capacity,
                                   uint32_t *count);
bool ViceEngineDebuggerListCheckpoints(ViceEngineDebuggerCheckpoint *checkpoints,
                                       uint32_t capacity,
                                       uint32_t *count);
bool ViceEngineDebuggerSetCheckpoint(uint32_t memorySpace,
                                     uint32_t startAddress,
                                     uint32_t endAddress,
                                     uint32_t operations,
                                     bool stops,
                                     bool enabled,
                                     bool temporary,
                                     uint32_t *checkpointID);
bool ViceEngineDebuggerDeleteCheckpoint(uint32_t checkpointID);
bool ViceEngineDebuggerSetCheckpointEnabled(uint32_t checkpointID, bool enabled);
bool ViceEngineDebuggerSetRegister(uint32_t memorySpace,
                                   uint32_t registerID,
                                   uint32_t value);
bool ViceEngineDebuggerSetCPU(uint32_t memorySpace, uint32_t cpuType);
bool ViceEngineDebuggerStep(uint32_t count, bool stepOver);
bool ViceEngineDebuggerReturn(void);
bool ViceEngineDebuggerContinue(void);

#ifdef __cplusplus
}
#endif

#endif
