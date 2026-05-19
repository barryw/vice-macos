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
    uint32_t ledColor;
    uint32_t ledIntensity;
    uint32_t errorIntensity;
    bool trackValid;
    uint32_t track;
    uint32_t halfTrack;
    uint32_t diskSide;
    bool sectorValid;
    uint32_t sector;
    uint32_t operation;
    int32_t driveStatusCode;
    const char *driveStatusText;
    const char *imagePath;
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
bool ViceEngineStartX64SC(const char *executablePath,
                          const char *dataDirectory,
                          int32_t sidModel,
                          bool soundEnabled,
                          int32_t soundVolume,
                          int32_t speedPercent,
                          bool warpEnabled,
                          const char *basicROM,
                          const char *kernalROM,
                          const char *characterROM);
bool ViceEngineIsRunning(void);
void ViceEngineSendKeyEvent(int64_t key, int32_t modifiers, bool pressed);
void ViceEngineReleaseAllKeys(void);
bool ViceEngineSetIntResource(const char *name, int32_t value);
bool ViceEngineSetStringResource(const char *name, const char *value);
bool ViceEngineSetJoystickValue(uint32_t port, uint32_t value);
bool ViceEngineSetPauseEnabled(bool paused);
bool ViceEngineTriggerMachineReset(bool hardReset);
bool ViceEngineSetWarpMode(bool enabled);
bool ViceEngineResetDrive(uint32_t unit);
bool ViceEngineAttachDisk(uint32_t unit, const char *path, bool autorun);
bool ViceEngineAttachCartridge(const char *path);
bool ViceEngineDetachCartridge(void);

#ifdef __cplusplus
}
#endif

#endif
