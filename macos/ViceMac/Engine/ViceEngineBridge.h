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

typedef void (*ViceEngineVideoFrameCallback)(const ViceEngineVideoFrame *frame,
                                             void *context);
typedef void (*ViceEngineDriveStatusCallback)(const ViceEngineDriveStatus *status,
                                              void *context);
typedef void (*ViceEngineCartridgeStatusCallback)(const ViceEngineCartridgeStatus *status,
                                                  void *context);

void ViceEngineSetVideoFrameCallback(ViceEngineVideoFrameCallback callback,
                                     void *context);
void ViceEngineSetDriveStatusCallback(ViceEngineDriveStatusCallback callback,
                                      void *context);
void ViceEngineSetCartridgeStatusCallback(ViceEngineCartridgeStatusCallback callback,
                                          void *context);
bool ViceEngineStartMachine(const char *machineID,
                            const char *dynamicLibraryPath,
                            int32_t argc,
                            const char * const *argv);
bool ViceEngineIsRunning(void);
void ViceEngineSendKeyEvent(int64_t key, int32_t modifiers, bool pressed);
void ViceEngineReleaseAllKeys(void);
bool ViceEngineFeedKeyboardText(const char *text);
bool ViceEngineSetIntResource(const char *name, int32_t value);
bool ViceEngineSetStringResource(const char *name, const char *value);
bool ViceEngineSetJoystickValue(uint32_t port, uint32_t value);
bool ViceEngineSetPauseEnabled(bool paused);
bool ViceEngineSetMachineModel(const char *model);
bool ViceEngineTriggerMachineReset(bool hardReset);
bool ViceEngineSetWarpMode(bool enabled);
bool ViceEngineResetDrive(uint32_t unit);
bool ViceEngineAttachDisk(uint32_t unit, uint32_t drive, const char *path, bool autorun);
bool ViceEnginePreviewDriveSound(uint32_t unit);
bool ViceEngineAttachCartridge(const char *path);
bool ViceEngineDetachCartridge(void);
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

#ifdef __cplusplus
}
#endif

#endif
