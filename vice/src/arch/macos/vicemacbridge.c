/*
 * vicemacbridge.c - Native macOS bridge for embedding VICE.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <dlfcn.h>
#include <pthread.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

#include "archdep.h"
#include "attach.h"
#include "autostart.h"
#include "c64model.h"
#include "c128model.h"
#include "cartridge.h"
#include "crt.h"
#include "datasette.h"
#include "drive.h"
#include "joystick.h"
#include "kbdbuf.h"
#include "keyboard.h"
#include "lib.h"
#include "log.h"
#include "machine.h"
#include "main.h"
#include "mainlock.h"
#include "monitor.h"
#include "monitor/mon_breakpoint.h"
#include "monitor/mon_disassemble.h"
#include "monitor/mon_register.h"
#include "monitor/montypes.h"
#include "mouse.h"
#include "mousedrv.h"
#include "resources.h"
#include "tape.h"
#include "ui.h"
#include "userport/userport.h"
#include "version.h"
#include "vicemacbridge.h"
#include "vsync.h"

#ifdef USE_SVN_REVISION
#include "svnversion.h"
#endif

#define VICEMAC_INPUT_QUEUE_CAPACITY 1024
#define VICEMAC_KEYBOARD_TEXT_QUEUE_CAPACITY 128
#define VICEMAC_KEYBOARD_TEXT_CAPACITY 4096
#define VICEMAC_RESOURCE_QUEUE_CAPACITY 256
#define VICEMAC_RESOURCE_NAME_CAPACITY 64
#define VICEMAC_MACHINE_MODEL_RESOURCE "__vicemacMachineModel"
#define VICEMAC_JOYSTICK_QUEUE_CAPACITY 256
#define VICEMAC_MOUSE_QUEUE_CAPACITY 1024
#define VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY 64
#define VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY 64
#define VICEMAC_DRIVE_REQUEST_QUEUE_CAPACITY 64
#define VICEMAC_MEDIA_COMMAND_QUEUE_CAPACITY 32
#define VICEMAC_TAPE_COMMAND_QUEUE_CAPACITY 32
#define VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY 16
#define VICEMAC_MEMORY_REQUEST_QUEUE_CAPACITY 64
#define VICEMAC_SNAPSHOT_REQUEST_QUEUE_CAPACITY 8
#define VICEMAC_DEBUGGER_REQUEST_QUEUE_CAPACITY 64
#define VICEMAC_PATH_CAPACITY 4096
#define VICEMAC_PROGRAM_NAME_CAPACITY 256
#define VICEMAC_CURRENT_MEMORY_BANK -1
#define VICEMAC_PLUS4MODEL_C16_PAL 0
#define VICEMAC_PLUS4MODEL_C16_NTSC 1
#define VICEMAC_PLUS4MODEL_PLUS4_PAL 2
#define VICEMAC_PLUS4MODEL_PLUS4_NTSC 3
#define VICEMAC_PLUS4MODEL_V364_NTSC 4
#define VICEMAC_PLUS4MODEL_232_NTSC 5
#define VICEMAC_PLUS4MODEL_UNKNOWN 99

typedef void (*vicemac_drive_sound_head_fn)(int track, int step, int unit);

typedef enum vicemac_machine_command_type_e {
    VICEMAC_MACHINE_COMMAND_PAUSE,
    VICEMAC_MACHINE_COMMAND_SYSTEM_TIME_SYNC,
    VICEMAC_MACHINE_COMMAND_RESET,
    VICEMAC_MACHINE_COMMAND_WARP,
    VICEMAC_MACHINE_COMMAND_QUIT
} vicemac_machine_command_type_t;

typedef enum vicemac_drive_command_type_e {
    VICEMAC_DRIVE_COMMAND_RESET,
    VICEMAC_DRIVE_COMMAND_ATTACH_DISK,
    VICEMAC_DRIVE_COMMAND_DETACH_DISK,
    VICEMAC_DRIVE_COMMAND_PREVIEW_SOUND
} vicemac_drive_command_type_t;

typedef enum vicemac_media_command_type_e {
    VICEMAC_MEDIA_COMMAND_AUTOSTART
} vicemac_media_command_type_t;

typedef enum vicemac_tape_command_type_e {
    VICEMAC_TAPE_COMMAND_ATTACH,
    VICEMAC_TAPE_COMMAND_DETACH,
    VICEMAC_TAPE_COMMAND_CONTROL
} vicemac_tape_command_type_t;

typedef enum vicemac_cartridge_command_type_e {
    VICEMAC_CARTRIDGE_COMMAND_ATTACH,
    VICEMAC_CARTRIDGE_COMMAND_DETACH
} vicemac_cartridge_command_type_t;

typedef enum vicemac_memory_request_type_e {
    VICEMAC_MEMORY_REQUEST_PEEK,
    VICEMAC_MEMORY_REQUEST_POKE
} vicemac_memory_request_type_t;

typedef enum vicemac_snapshot_request_type_e {
    VICEMAC_SNAPSHOT_REQUEST_SAVE,
    VICEMAC_SNAPSHOT_REQUEST_LOAD
} vicemac_snapshot_request_type_t;

typedef enum vicemac_resource_request_type_e {
    VICEMAC_RESOURCE_REQUEST_INT,
    VICEMAC_RESOURCE_REQUEST_STRING
} vicemac_resource_request_type_t;

typedef enum vicemac_debugger_request_type_e {
    VICEMAC_DEBUGGER_REQUEST_SNAPSHOT,
    VICEMAC_DEBUGGER_REQUEST_DISASSEMBLE,
    VICEMAC_DEBUGGER_REQUEST_LIST_CHECKPOINTS,
    VICEMAC_DEBUGGER_REQUEST_SET_CHECKPOINT,
    VICEMAC_DEBUGGER_REQUEST_DELETE_CHECKPOINT,
    VICEMAC_DEBUGGER_REQUEST_SET_CHECKPOINT_ENABLED,
    VICEMAC_DEBUGGER_REQUEST_SET_REGISTER,
    VICEMAC_DEBUGGER_REQUEST_SET_CPU,
    VICEMAC_DEBUGGER_REQUEST_STEP,
    VICEMAC_DEBUGGER_REQUEST_RETURN,
    VICEMAC_DEBUGGER_REQUEST_CONTINUE
} vicemac_debugger_request_type_t;

typedef struct vicemac_input_event_s {
    int clear;
    signed long key;
    int mod;
    int pressed;
} vicemac_input_event_t;

typedef struct vicemac_keyboard_text_event_s {
    char text[VICEMAC_KEYBOARD_TEXT_CAPACITY];
} vicemac_keyboard_text_event_t;

typedef struct vicemac_resource_int_event_s {
    char name[VICEMAC_RESOURCE_NAME_CAPACITY];
    int value;
} vicemac_resource_int_event_t;

typedef struct vicemac_resource_string_event_s {
    char name[VICEMAC_RESOURCE_NAME_CAPACITY];
    char value[VICEMAC_PATH_CAPACITY];
} vicemac_resource_string_event_t;

typedef struct vicemac_joystick_event_s {
    uint32_t port;
    uint32_t value;
} vicemac_joystick_event_t;

typedef enum vicemac_mouse_event_type_e {
    VICEMAC_MOUSE_EVENT_MOVE,
    VICEMAC_MOUSE_EVENT_BUTTON,
    VICEMAC_MOUSE_EVENT_RESET
} vicemac_mouse_event_type_t;

typedef struct vicemac_mouse_event_s {
    vicemac_mouse_event_type_t type;
    float delta_x;
    float delta_y;
    uint32_t button;
    int pressed;
} vicemac_mouse_event_t;

typedef struct vicemac_machine_command_s {
    vicemac_machine_command_type_t type;
    int value;
} vicemac_machine_command_t;

typedef struct vicemac_drive_command_s {
    vicemac_drive_command_type_t type;
    uint32_t unit;
    uint32_t drive;
    int run_mode;
    char path[VICEMAC_PATH_CAPACITY];
    char program_name[VICEMAC_PROGRAM_NAME_CAPACITY];
} vicemac_drive_command_t;

typedef struct vicemac_drive_attach_request_s {
    uint32_t unit;
    uint32_t drive;
    int run_mode;
    char path[VICEMAC_PATH_CAPACITY];
    char program_name[VICEMAC_PROGRAM_NAME_CAPACITY];
    int completed;
    int success;
    pthread_mutex_t mutex;
    pthread_cond_t condition;
} vicemac_drive_attach_request_t;

typedef struct vicemac_media_command_s {
    vicemac_media_command_type_t type;
    int run_mode;
    char path[VICEMAC_PATH_CAPACITY];
} vicemac_media_command_t;

typedef struct vicemac_tape_command_s {
    vicemac_tape_command_type_t type;
    uint32_t unit;
    int control;
    char path[VICEMAC_PATH_CAPACITY];
} vicemac_tape_command_t;

typedef struct vicemac_cartridge_command_s {
    vicemac_cartridge_command_type_t type;
    char path[VICEMAC_PATH_CAPACITY];
} vicemac_cartridge_command_t;

typedef struct vicemac_memory_request_s {
    vicemac_memory_request_type_t type;
    uint32_t memspace;
    int32_t bank;
    uint32_t address;
    uint32_t length;
    uint8_t *read_buffer;
    const uint8_t *write_bytes;
    int completed;
    int success;
    pthread_mutex_t mutex;
    pthread_cond_t condition;
} vicemac_memory_request_t;

typedef struct vicemac_snapshot_request_s {
    vicemac_snapshot_request_type_t type;
    int save_roms;
    int save_disks;
    char path[VICEMAC_PATH_CAPACITY];
    int completed;
    int success;
    pthread_mutex_t mutex;
    pthread_cond_t condition;
} vicemac_snapshot_request_t;

typedef struct vicemac_resource_request_s {
    vicemac_resource_request_type_t type;
    char name[VICEMAC_RESOURCE_NAME_CAPACITY];
    int int_value;
    char *string_buffer;
    uint32_t string_buffer_capacity;
    int completed;
    int success;
    pthread_mutex_t mutex;
    pthread_cond_t condition;
} vicemac_resource_request_t;

typedef struct vicemac_debugger_request_s {
    vicemac_debugger_request_type_t type;
    uint32_t memspace;
    int32_t bank;
    uint32_t address;
    uint32_t end_address;
    uint32_t count;
    uint32_t operations;
    uint32_t checkpoint_id;
    uint32_t register_id;
    uint32_t cpu_type;
    uint32_t value;
    int enabled;
    int stops;
    int temporary;
    int step_over;
    vicemac_debugger_snapshot_t *snapshot;
    vicemac_debugger_disassembly_line_t *disassembly_lines;
    vicemac_debugger_checkpoint_t *checkpoints;
    uint32_t capacity;
    uint32_t *output_count;
    uint32_t *output_id;
    int completed;
    int success;
    pthread_mutex_t mutex;
    pthread_cond_t condition;
} vicemac_debugger_request_t;

static vicemac_video_frame_callback_t video_frame_callback = 0;
static void *video_frame_context = 0;
static vicemac_drive_status_callback_t drive_status_callback = 0;
static void *drive_status_context = 0;
static vicemac_cartridge_status_callback_t cartridge_status_callback = 0;
static void *cartridge_status_context = 0;
static vicemac_vsid_state_callback_t vsid_state_callback = 0;
static void *vsid_state_context = 0;
static vicemac_audio_samples_callback_t audio_samples_callback = 0;
static void *audio_samples_context = 0;
static vicemac_sid_voice_samples_callback_t sid_voice_samples_callback = 0;
static void *sid_voice_samples_context = 0;
static uint64_t video_frame_sequence = 0;
static uint64_t audio_samples_sequence = 0;
static uint64_t sid_voice_samples_sequence = 0;
#define VICEMAC_AUDIO_VISUALIZER_FPS 30U
#define VICEMAC_SID_VOICE_VISUALIZER_FPS 20U
#define VICEMAC_SID_VOICE_VISUALIZER_MAX_CHIPS 8U
static uint32_t audio_samples_pending_frames = 0;
static uint32_t sid_voice_samples_pending_frames[VICEMAC_SID_VOICE_VISUALIZER_MAX_CHIPS];
static pthread_mutex_t input_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_input_event_t input_queue[VICEMAC_INPUT_QUEUE_CAPACITY];
static unsigned int input_queue_read = 0;
static unsigned int input_queue_write = 0;
static pthread_mutex_t keyboard_text_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_keyboard_text_event_t keyboard_text_queue[VICEMAC_KEYBOARD_TEXT_QUEUE_CAPACITY];
static unsigned int keyboard_text_queue_read = 0;
static unsigned int keyboard_text_queue_write = 0;
static pthread_mutex_t resource_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_resource_int_event_t resource_queue[VICEMAC_RESOURCE_QUEUE_CAPACITY];
static unsigned int resource_queue_read = 0;
static unsigned int resource_queue_write = 0;
static pthread_mutex_t resource_string_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_resource_string_event_t resource_string_queue[VICEMAC_RESOURCE_QUEUE_CAPACITY];
static unsigned int resource_string_queue_read = 0;
static unsigned int resource_string_queue_write = 0;
static pthread_mutex_t resource_request_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_resource_request_t *resource_request_queue[VICEMAC_RESOURCE_QUEUE_CAPACITY];
static unsigned int resource_request_queue_read = 0;
static unsigned int resource_request_queue_write = 0;
static pthread_mutex_t joystick_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_joystick_event_t joystick_queue[VICEMAC_JOYSTICK_QUEUE_CAPACITY];
static unsigned int joystick_queue_read = 0;
static unsigned int joystick_queue_write = 0;
static pthread_mutex_t mouse_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_mouse_event_t mouse_queue[VICEMAC_MOUSE_QUEUE_CAPACITY];
static unsigned int mouse_queue_read = 0;
static unsigned int mouse_queue_write = 0;
static pthread_mutex_t machine_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_machine_command_t machine_command_queue[VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY];
static unsigned int machine_command_queue_read = 0;
static unsigned int machine_command_queue_write = 0;
static pthread_mutex_t drive_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_drive_command_t drive_command_queue[VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY];
static unsigned int drive_command_queue_read = 0;
static unsigned int drive_command_queue_write = 0;
static pthread_mutex_t drive_attach_request_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_drive_attach_request_t *drive_attach_request_queue[VICEMAC_DRIVE_REQUEST_QUEUE_CAPACITY];
static unsigned int drive_attach_request_queue_read = 0;
static unsigned int drive_attach_request_queue_write = 0;
static pthread_mutex_t media_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_media_command_t media_command_queue[VICEMAC_MEDIA_COMMAND_QUEUE_CAPACITY];
static unsigned int media_command_queue_read = 0;
static unsigned int media_command_queue_write = 0;
static pthread_mutex_t tape_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_tape_command_t tape_command_queue[VICEMAC_TAPE_COMMAND_QUEUE_CAPACITY];
static unsigned int tape_command_queue_read = 0;
static unsigned int tape_command_queue_write = 0;
static pthread_mutex_t cartridge_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_cartridge_command_t cartridge_command_queue[VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY];
static unsigned int cartridge_command_queue_read = 0;
static unsigned int cartridge_command_queue_write = 0;
static pthread_mutex_t memory_request_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_memory_request_t *memory_request_queue[VICEMAC_MEMORY_REQUEST_QUEUE_CAPACITY];
static unsigned int memory_request_queue_read = 0;
static unsigned int memory_request_queue_write = 0;
static pthread_mutex_t snapshot_request_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_snapshot_request_t *snapshot_request_queue[VICEMAC_SNAPSHOT_REQUEST_QUEUE_CAPACITY];
static unsigned int snapshot_request_queue_read = 0;
static unsigned int snapshot_request_queue_write = 0;
static pthread_mutex_t debugger_request_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_debugger_request_t *debugger_request_queue[VICEMAC_DEBUGGER_REQUEST_QUEUE_CAPACITY];
static unsigned int debugger_request_queue_read = 0;
static unsigned int debugger_request_queue_write = 0;

static unsigned int vicemac_queue_next(unsigned int index, unsigned int capacity)
{
    return (index + 1) % capacity;
}

const char *vicemac_get_vice_version(void)
{
#ifdef USE_SVN_REVISION
    static char version[128];

    snprintf(version, sizeof(version), "%s r%s", VERSION, VICE_SVN_REV_STRING);
    return version;
#else
    return VERSION;
#endif
}

int vicemac_bridge_abi_version(void)
{
    return VICEMAC_BRIDGE_ABI_VERSION;
}

static void vicemac_copy_cstring(char *destination, size_t destination_size, const char *source)
{
    if (destination_size == 0) {
        return;
    }

    if (source == 0) {
        destination[0] = '\0';
        return;
    }

    strncpy(destination, source, destination_size - 1);
    destination[destination_size - 1] = '\0';
}

static int vicemac_queue_push(pthread_mutex_t *mutex,
                              void *queue,
                              size_t element_size,
                              unsigned int capacity,
                              unsigned int *read_index,
                              unsigned int *write_index,
                              const void *event)
{
    unsigned int next_write;
    char *slot;

    pthread_mutex_lock(mutex);

    next_write = vicemac_queue_next(*write_index, capacity);
    if (next_write == *read_index) {
        *read_index = vicemac_queue_next(*read_index, capacity);
    }

    slot = ((char *)queue) + ((size_t)*write_index * element_size);
    memcpy(slot, event, element_size);
    *write_index = next_write;

    pthread_mutex_unlock(mutex);
    return 1;
}

static int vicemac_queue_pop(pthread_mutex_t *mutex,
                             void *queue,
                             size_t element_size,
                             unsigned int capacity,
                             unsigned int *read_index,
                             unsigned int *write_index,
                             void *event)
{
    int has_event = 0;

    pthread_mutex_lock(mutex);

    if (*read_index != *write_index) {
        char *slot = ((char *)queue) + ((size_t)*read_index * element_size);
        memcpy(event, slot, element_size);
        *read_index = vicemac_queue_next(*read_index, capacity);
        has_event = 1;
    }

    pthread_mutex_unlock(mutex);
    return has_event;
}

static int vicemac_memory_queue_push(vicemac_memory_request_t *request)
{
    unsigned int next_write;

    pthread_mutex_lock(&memory_request_queue_mutex);

    next_write = vicemac_queue_next(memory_request_queue_write,
                                    VICEMAC_MEMORY_REQUEST_QUEUE_CAPACITY);
    if (next_write == memory_request_queue_read) {
        pthread_mutex_unlock(&memory_request_queue_mutex);
        return 0;
    }

    memory_request_queue[memory_request_queue_write] = request;
    memory_request_queue_write = next_write;

    pthread_mutex_unlock(&memory_request_queue_mutex);
    return 1;
}

static int vicemac_memory_queue_pop(vicemac_memory_request_t **request)
{
    int has_request = 0;

    pthread_mutex_lock(&memory_request_queue_mutex);

    if (memory_request_queue_read != memory_request_queue_write) {
        *request = memory_request_queue[memory_request_queue_read];
        memory_request_queue[memory_request_queue_read] = 0;
        memory_request_queue_read = vicemac_queue_next(memory_request_queue_read,
                                                       VICEMAC_MEMORY_REQUEST_QUEUE_CAPACITY);
        has_request = 1;
    }

    pthread_mutex_unlock(&memory_request_queue_mutex);
    return has_request;
}

static int vicemac_snapshot_queue_push(vicemac_snapshot_request_t *request)
{
    unsigned int next_write;

    pthread_mutex_lock(&snapshot_request_queue_mutex);

    next_write = vicemac_queue_next(snapshot_request_queue_write,
                                    VICEMAC_SNAPSHOT_REQUEST_QUEUE_CAPACITY);
    if (next_write == snapshot_request_queue_read) {
        pthread_mutex_unlock(&snapshot_request_queue_mutex);
        return 0;
    }

    snapshot_request_queue[snapshot_request_queue_write] = request;
    snapshot_request_queue_write = next_write;

    pthread_mutex_unlock(&snapshot_request_queue_mutex);
    return 1;
}

static int vicemac_snapshot_queue_pop(vicemac_snapshot_request_t **request)
{
    int has_request = 0;

    pthread_mutex_lock(&snapshot_request_queue_mutex);

    if (snapshot_request_queue_read != snapshot_request_queue_write) {
        *request = snapshot_request_queue[snapshot_request_queue_read];
        snapshot_request_queue[snapshot_request_queue_read] = 0;
        snapshot_request_queue_read = vicemac_queue_next(snapshot_request_queue_read,
                                                         VICEMAC_SNAPSHOT_REQUEST_QUEUE_CAPACITY);
        has_request = 1;
    }

    pthread_mutex_unlock(&snapshot_request_queue_mutex);
    return has_request;
}

static int vicemac_resource_request_queue_push(vicemac_resource_request_t *request)
{
    unsigned int next_write;

    pthread_mutex_lock(&resource_request_queue_mutex);

    next_write = vicemac_queue_next(resource_request_queue_write,
                                    VICEMAC_RESOURCE_QUEUE_CAPACITY);
    if (next_write == resource_request_queue_read) {
        pthread_mutex_unlock(&resource_request_queue_mutex);
        return 0;
    }

    resource_request_queue[resource_request_queue_write] = request;
    resource_request_queue_write = next_write;

    pthread_mutex_unlock(&resource_request_queue_mutex);
    return 1;
}

static int vicemac_resource_request_queue_pop(vicemac_resource_request_t **request)
{
    int has_request = 0;

    pthread_mutex_lock(&resource_request_queue_mutex);

    if (resource_request_queue_read != resource_request_queue_write) {
        *request = resource_request_queue[resource_request_queue_read];
        resource_request_queue[resource_request_queue_read] = 0;
        resource_request_queue_read = vicemac_queue_next(resource_request_queue_read,
                                                         VICEMAC_RESOURCE_QUEUE_CAPACITY);
        has_request = 1;
    }

    pthread_mutex_unlock(&resource_request_queue_mutex);
    return has_request;
}

static int vicemac_drive_attach_request_queue_push(vicemac_drive_attach_request_t *request)
{
    unsigned int next_write;

    pthread_mutex_lock(&drive_attach_request_queue_mutex);

    next_write = vicemac_queue_next(drive_attach_request_queue_write,
                                    VICEMAC_DRIVE_REQUEST_QUEUE_CAPACITY);
    if (next_write == drive_attach_request_queue_read) {
        pthread_mutex_unlock(&drive_attach_request_queue_mutex);
        return 0;
    }

    drive_attach_request_queue[drive_attach_request_queue_write] = request;
    drive_attach_request_queue_write = next_write;

    pthread_mutex_unlock(&drive_attach_request_queue_mutex);
    return 1;
}

static int vicemac_drive_attach_request_queue_pop(vicemac_drive_attach_request_t **request)
{
    int has_request = 0;

    pthread_mutex_lock(&drive_attach_request_queue_mutex);

    if (drive_attach_request_queue_read != drive_attach_request_queue_write) {
        *request = drive_attach_request_queue[drive_attach_request_queue_read];
        drive_attach_request_queue[drive_attach_request_queue_read] = 0;
        drive_attach_request_queue_read = vicemac_queue_next(drive_attach_request_queue_read,
                                                             VICEMAC_DRIVE_REQUEST_QUEUE_CAPACITY);
        has_request = 1;
    }

    pthread_mutex_unlock(&drive_attach_request_queue_mutex);
    return has_request;
}

static int vicemac_debugger_queue_push(vicemac_debugger_request_t *request)
{
    unsigned int next_write;

    pthread_mutex_lock(&debugger_request_queue_mutex);

    next_write = vicemac_queue_next(debugger_request_queue_write,
                                    VICEMAC_DEBUGGER_REQUEST_QUEUE_CAPACITY);
    if (next_write == debugger_request_queue_read) {
        pthread_mutex_unlock(&debugger_request_queue_mutex);
        return 0;
    }

    debugger_request_queue[debugger_request_queue_write] = request;
    debugger_request_queue_write = next_write;

    pthread_mutex_unlock(&debugger_request_queue_mutex);
    return 1;
}

static int vicemac_debugger_queue_pop(vicemac_debugger_request_t **request)
{
    int has_request = 0;

    pthread_mutex_lock(&debugger_request_queue_mutex);

    if (debugger_request_queue_read != debugger_request_queue_write) {
        *request = debugger_request_queue[debugger_request_queue_read];
        debugger_request_queue[debugger_request_queue_read] = 0;
        debugger_request_queue_read = vicemac_queue_next(debugger_request_queue_read,
                                                         VICEMAC_DEBUGGER_REQUEST_QUEUE_CAPACITY);
        has_request = 1;
    }

    pthread_mutex_unlock(&debugger_request_queue_mutex);
    return has_request;
}

static void vicemac_complete_memory_request(vicemac_memory_request_t *request, int success)
{
    pthread_mutex_lock(&request->mutex);
    request->success = success;
    request->completed = 1;
    pthread_cond_signal(&request->condition);
    pthread_mutex_unlock(&request->mutex);
}

static void vicemac_complete_snapshot_request(vicemac_snapshot_request_t *request, int success)
{
    pthread_mutex_lock(&request->mutex);
    request->success = success;
    request->completed = 1;
    pthread_cond_signal(&request->condition);
    pthread_mutex_unlock(&request->mutex);
}

static void vicemac_complete_resource_request(vicemac_resource_request_t *request, int success)
{
    pthread_mutex_lock(&request->mutex);
    request->success = success;
    request->completed = 1;
    pthread_cond_signal(&request->condition);
    pthread_mutex_unlock(&request->mutex);
}

static void vicemac_complete_debugger_request(vicemac_debugger_request_t *request, int success)
{
    pthread_mutex_lock(&request->mutex);
    request->success = success;
    request->completed = 1;
    pthread_cond_signal(&request->condition);
    pthread_mutex_unlock(&request->mutex);
}

static void vicemac_preview_drive_sound(int unit)
{
    static vicemac_drive_sound_head_fn drive_sound_head_fn = 0;
    static int did_resolve = 0;

    if (!did_resolve) {
        drive_sound_head_fn = (vicemac_drive_sound_head_fn)dlsym(RTLD_DEFAULT,
                                                                 "drive_sound_head");
        did_resolve = 1;
    }

    if (drive_sound_head_fn != 0) {
        drive_sound_head_fn(18, 1, unit);
    }
}

void vicemac_set_video_frame_callback(vicemac_video_frame_callback_t callback,
                                      void *context)
{
    video_frame_callback = callback;
    video_frame_context = context;
}

void vicemac_set_drive_status_callback(vicemac_drive_status_callback_t callback,
                                       void *context)
{
    drive_status_callback = callback;
    drive_status_context = context;
}

void vicemac_set_cartridge_status_callback(vicemac_cartridge_status_callback_t callback,
                                           void *context)
{
    cartridge_status_callback = callback;
    cartridge_status_context = context;
}

void vicemac_set_vsid_state_callback(vicemac_vsid_state_callback_t callback,
                                     void *context)
{
    vsid_state_callback = callback;
    vsid_state_context = context;
}

void vicemac_set_audio_samples_callback(vicemac_audio_samples_callback_t callback,
                                        void *context)
{
    audio_samples_callback = callback;
    audio_samples_context = context;
    audio_samples_pending_frames = 0;
    audio_samples_sequence = 0;
}

void vicemac_set_sid_voice_samples_callback(vicemac_sid_voice_samples_callback_t callback,
                                            void *context)
{
    sid_voice_samples_callback = callback;
    sid_voice_samples_context = context;
    memset(sid_voice_samples_pending_frames, 0, sizeof(sid_voice_samples_pending_frames));
    sid_voice_samples_sequence = 0;
}

int vicemac_has_video_frame_callback(void)
{
    return video_frame_callback != 0;
}

void vicemac_publish_vsid_state(const vicemac_vsid_state_t *state)
{
    if (vsid_state_callback != 0 && state != 0) {
        vsid_state_callback(state, vsid_state_context);
    }
}

static int vicemac_should_publish_visualizer_samples(uint32_t *pending_frames,
                                                     uint32_t frame_count,
                                                     uint32_t sample_rate,
                                                     uint32_t frames_per_second)
{
    uint64_t accumulated_frames;
    uint32_t frame_interval;

    if (pending_frames == 0 || frame_count == 0) {
        return 0;
    }

    if (sample_rate == 0 || frames_per_second == 0) {
        return 1;
    }

    frame_interval = sample_rate / frames_per_second;
    if (frame_interval == 0) {
        frame_interval = 1;
    }

    accumulated_frames = (uint64_t)*pending_frames + frame_count;
    if (accumulated_frames < frame_interval) {
        *pending_frames = (uint32_t)accumulated_frames;
        return 0;
    }

    *pending_frames = (uint32_t)(accumulated_frames % frame_interval);
    return 1;
}

int vicemac_should_capture_sid_voice_samples(uint32_t chip_index,
                                             uint32_t frame_count,
                                             uint32_t sample_rate)
{
    if (sid_voice_samples_callback == 0 || frame_count == 0) {
        return 0;
    }

    if (chip_index >= VICEMAC_SID_VOICE_VISUALIZER_MAX_CHIPS) {
        chip_index = VICEMAC_SID_VOICE_VISUALIZER_MAX_CHIPS - 1;
    }

    return vicemac_should_publish_visualizer_samples(&sid_voice_samples_pending_frames[chip_index],
                                                     frame_count,
                                                     sample_rate,
                                                     VICEMAC_SID_VOICE_VISUALIZER_FPS);
}

void vicemac_publish_audio_samples(const int16_t *samples,
                                   uint32_t frame_count,
                                   uint32_t channel_count,
                                   uint32_t sample_rate)
{
    vicemac_audio_samples_t packet;

    if (audio_samples_callback == 0 || samples == 0 || frame_count == 0 || channel_count == 0) {
        return;
    }

    if (!vicemac_should_publish_visualizer_samples(&audio_samples_pending_frames,
                                                   frame_count,
                                                   sample_rate,
                                                   VICEMAC_AUDIO_VISUALIZER_FPS)) {
        return;
    }

    packet.samples = samples;
    packet.frame_count = frame_count;
    packet.channel_count = channel_count;
    packet.sample_rate = sample_rate;
    packet.sequence = ++audio_samples_sequence;

    audio_samples_callback(&packet, audio_samples_context);
}

void vicemac_publish_sid_voice_samples(const int16_t *samples,
                                       uint32_t frame_count,
                                       uint32_t voice_count,
                                       uint32_t chip_index,
                                       uint32_t sample_rate,
                                       uint32_t clock_rate,
                                       const uint16_t *frequency,
                                       const uint8_t *control)
{
    vicemac_sid_voice_samples_t packet;
    uint32_t voice;

    if (sid_voice_samples_callback == 0 || samples == 0 || frame_count == 0 || voice_count == 0) {
        return;
    }

    if (voice_count > VICEMAC_SID_VOICE_COUNT) {
        voice_count = VICEMAC_SID_VOICE_COUNT;
    }

    packet.samples = samples;
    packet.frame_count = frame_count;
    packet.voice_count = voice_count;
    packet.chip_index = chip_index;
    packet.sample_rate = sample_rate;
    packet.clock_rate = clock_rate;
    for (voice = 0; voice < VICEMAC_SID_VOICE_COUNT; voice++) {
        packet.frequency[voice] = frequency != 0 && voice < voice_count ? frequency[voice] : 0;
        packet.control[voice] = control != 0 && voice < voice_count ? control[voice] : 0;
    }
    packet.sequence = ++sid_voice_samples_sequence;

    sid_voice_samples_callback(&packet, sid_voice_samples_context);
}

void vicemac_publish_video_frame(uint32_t width,
                                 uint32_t height,
                                 uint32_t stride,
                                 const uint8_t *pixels)
{
    vicemac_video_frame_t frame;

    if (video_frame_callback == 0 || pixels == 0 || width == 0 || height == 0 || stride == 0) {
        return;
    }

    frame.width = width;
    frame.height = height;
    frame.stride = stride;
    frame.pixel_format = VICEMAC_PIXEL_FORMAT_RGBA8;
    frame.sequence = ++video_frame_sequence;
    frame.pixels = pixels;

    video_frame_callback(&frame, video_frame_context);
}

void vicemac_publish_drive_status(uint32_t unit,
                                  uint32_t enabled,
                                  int32_t drive_type,
                                  uint32_t active_drive_number,
                                  uint32_t led_color,
                                  uint32_t led_pwm1,
                                  uint32_t led_pwm2,
                                  uint32_t drive0_led_intensity,
                                  uint32_t drive1_led_intensity,
                                  uint32_t track_valid,
                                  uint32_t track,
                                  uint32_t half_track,
                                  uint32_t disk_side,
                                  int32_t drive_status_code,
                                  const char *drive_status_text,
                                  const char *image_path,
                                  const char *drive0_image_path,
                                  const char *drive1_image_path)
{
    vicemac_drive_status_t status;

    if (drive_status_callback == 0) {
        return;
    }

    status.unit = unit;
    status.enabled = enabled ? 1U : 0U;
    status.drive_type = drive_type;
    status.active_drive_number = active_drive_number;
    status.led_color = led_color;
    status.led_pwm1 = led_pwm1;
    status.led_pwm2 = led_pwm2;
    status.drive0_led_intensity = drive0_led_intensity;
    status.drive1_led_intensity = drive1_led_intensity;
    status.track_valid = track_valid ? 1U : 0U;
    status.track = track;
    status.half_track = half_track;
    status.disk_side = disk_side;
    status.drive_status_code = drive_status_code;
    status.drive_status_text = drive_status_text;
    status.image_path = image_path;
    status.drive0_image_path = drive0_image_path;
    status.drive1_image_path = drive1_image_path;

    drive_status_callback(&status, drive_status_context);
}

static const char *vicemac_cartridge_name_for_id(int cartridge_id)
{
    cartridge_info_t *info;

    if (cartridge_id == CARTRIDGE_NONE) {
        return 0;
    }

    for (info = cartridge_get_info_list(); info != 0 && info->name != 0; ++info) {
        if (info->crtid == cartridge_id) {
            return info->name;
        }
    }

    return "Cartridge";
}

static uint32_t vicemac_cartridge_flags_for_id(int cartridge_id)
{
    cartridge_info_t *info;

    if (cartridge_id == CARTRIDGE_NONE) {
        return 0;
    }

    for (info = cartridge_get_info_list(); info != 0 && info->name != 0; ++info) {
        if (info->crtid == cartridge_id) {
            return info->flags;
        }
    }

    return 0;
}

static int vicemac_read_crt_rom_metadata(const char *path,
                                         uint32_t *rom_size,
                                         uint32_t *chip_count,
                                         uint32_t *bank_count)
{
    enum {
        VICEMAC_CRT_BANK_WORDS = 2048
    };

    uint32_t seen_banks[VICEMAC_CRT_BANK_WORDS];
    crt_chip_header_t chip;
    crt_header_t header;
    FILE *fd;

    *rom_size = 0;
    *chip_count = 0;
    *bank_count = 0;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    fd = crt_open(path, &header);
    if (fd == 0) {
        return 0;
    }

    memset(seen_banks, 0, sizeof(seen_banks));
    while (crt_read_chip_header(&chip, fd) == 0) {
        uint32_t bank_word = chip.bank / 32U;
        uint32_t bank_mask = 1U << (chip.bank % 32U);

        if (chip.size > UINT32_MAX - *rom_size ||
            *chip_count == UINT32_MAX) {
            break;
        }

        *rom_size += chip.size;
        *chip_count += 1U;

        if ((seen_banks[bank_word] & bank_mask) == 0) {
            seen_banks[bank_word] |= bank_mask;
            *bank_count += 1U;
        }

        if (fseek(fd, (long)chip.size + (long)chip.skip, SEEK_CUR) != 0) {
            break;
        }
    }

    fclose(fd);
    return *chip_count > 0;
}

static void vicemac_publish_current_cartridge_status(void)
{
    vicemac_cartridge_status_t status;
    int cartridge_id;
    const char *image_path;

    if (cartridge_status_callback == 0) {
        return;
    }

    cartridge_id = cartridge_get_id(0);
    status.attached = cartridge_id == CARTRIDGE_NONE ? 0U : 1U;
    status.cartridge_id = cartridge_id;
    status.cartridge_flags = vicemac_cartridge_flags_for_id(cartridge_id);
    status.cartridge_name = vicemac_cartridge_name_for_id(cartridge_id);
    status.rom_size = 0;
    status.chip_count = 0;
    status.bank_count = 0;
    image_path = status.attached ? cartridge_get_filename_by_slot(0) : 0;
    status.image_path = image_path;

    if (status.attached) {
        (void)vicemac_read_crt_rom_metadata(image_path,
                                            &status.rom_size,
                                            &status.chip_count,
                                            &status.bank_count);
    }

    cartridge_status_callback(&status, cartridge_status_context);
}

int vicemac_queue_key_event(signed long key, int mod, int pressed)
{
    vicemac_input_event_t event;

    if (key == 0) {
        return 0;
    }

    event.clear = 0;
    event.key = key;
    event.mod = mod;
    event.pressed = pressed ? 1 : 0;

    return vicemac_queue_push(&input_queue_mutex,
                              input_queue,
                              sizeof(input_queue[0]),
                              VICEMAC_INPUT_QUEUE_CAPACITY,
                              &input_queue_read,
                              &input_queue_write,
                              &event);
}

int vicemac_queue_keyboard_clear(void)
{
    vicemac_input_event_t event;

    memset(&event, 0, sizeof(event));
    event.clear = 1;

    return vicemac_queue_push(&input_queue_mutex,
                              input_queue,
                              sizeof(input_queue[0]),
                              VICEMAC_INPUT_QUEUE_CAPACITY,
                              &input_queue_read,
                              &input_queue_write,
                              &event);
}

int vicemac_queue_keyboard_text(const char *text)
{
    vicemac_keyboard_text_event_t event;

    if (text == 0 || text[0] == '\0'
        || strlen(text) >= sizeof(event.text)) {
        return 0;
    }

    memset(&event, 0, sizeof(event));
    vicemac_copy_cstring(event.text, sizeof(event.text), text);

    return vicemac_queue_push(&keyboard_text_queue_mutex,
                              keyboard_text_queue,
                              sizeof(keyboard_text_queue[0]),
                              VICEMAC_KEYBOARD_TEXT_QUEUE_CAPACITY,
                              &keyboard_text_queue_read,
                              &keyboard_text_queue_write,
                              &event);
}

int vicemac_queue_resource_int(const char *name, int value)
{
    vicemac_resource_int_event_t event;

    if (name == 0 || name[0] == '\0') {
        return 0;
    }

    memset(&event, 0, sizeof(event));
    vicemac_copy_cstring(event.name, sizeof(event.name), name);
    event.value = value;

    return vicemac_queue_push(&resource_queue_mutex,
                              resource_queue,
                              sizeof(resource_queue[0]),
                              VICEMAC_RESOURCE_QUEUE_CAPACITY,
                              &resource_queue_read,
                              &resource_queue_write,
                              &event);
}

int vicemac_queue_resource_string(const char *name, const char *value)
{
    vicemac_resource_string_event_t event;

    if (name == 0 || name[0] == '\0' || value == 0) {
        return 0;
    }

    memset(&event, 0, sizeof(event));
    vicemac_copy_cstring(event.name, sizeof(event.name), name);
    vicemac_copy_cstring(event.value, sizeof(event.value), value);

    return vicemac_queue_push(&resource_string_queue_mutex,
                              resource_string_queue,
                              sizeof(resource_string_queue[0]),
                              VICEMAC_RESOURCE_QUEUE_CAPACITY,
                              &resource_string_queue_read,
                              &resource_string_queue_write,
                              &event);
}

static int vicemac_perform_resource_request(vicemac_resource_request_type_t type,
                                            const char *name,
                                            int *int_value,
                                            char *string_buffer,
                                            uint32_t string_buffer_capacity)
{
    vicemac_resource_request_t request;
    int success;

    if (name == 0 || name[0] == '\0'
        || strlen(name) >= VICEMAC_RESOURCE_NAME_CAPACITY) {
        return 0;
    }

    if ((type == VICEMAC_RESOURCE_REQUEST_INT && int_value == 0)
        || (type == VICEMAC_RESOURCE_REQUEST_STRING
            && (string_buffer == 0 || string_buffer_capacity == 0))) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.type = type;
    vicemac_copy_cstring(request.name, sizeof(request.name), name);
    request.string_buffer = string_buffer;
    request.string_buffer_capacity = string_buffer_capacity;

    if (pthread_mutex_init(&request.mutex, 0) != 0) {
        return 0;
    }
    if (pthread_cond_init(&request.condition, 0) != 0) {
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    if (!vicemac_resource_request_queue_push(&request)) {
        pthread_cond_destroy(&request.condition);
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    pthread_mutex_lock(&request.mutex);
    while (!request.completed) {
        pthread_cond_wait(&request.condition, &request.mutex);
    }
    success = request.success;
    if (success && type == VICEMAC_RESOURCE_REQUEST_INT) {
        *int_value = request.int_value;
    }
    pthread_mutex_unlock(&request.mutex);

    pthread_cond_destroy(&request.condition);
    pthread_mutex_destroy(&request.mutex);
    return success;
}

int vicemac_get_resource_int(const char *name, int *value)
{
    return vicemac_perform_resource_request(VICEMAC_RESOURCE_REQUEST_INT,
                                            name,
                                            value,
                                            0,
                                            0);
}

int vicemac_get_resource_string(const char *name, char *buffer, uint32_t buffer_capacity)
{
    return vicemac_perform_resource_request(VICEMAC_RESOURCE_REQUEST_STRING,
                                            name,
                                            0,
                                            buffer,
                                            buffer_capacity);
}

static void vicemac_complete_drive_attach_request(vicemac_drive_attach_request_t *request,
                                                  int success)
{
    pthread_mutex_lock(&request->mutex);
    request->success = success ? 1 : 0;
    request->completed = 1;
    pthread_cond_signal(&request->condition);
    pthread_mutex_unlock(&request->mutex);
}

static int vicemac_perform_drive_attach_request(uint32_t unit,
                                                uint32_t drive,
                                                const char *path,
                                                const char *program_name,
                                                int run_mode)
{
    vicemac_drive_attach_request_t request;
    int success;

    if (path == 0 || path[0] == '\0' || strlen(path) >= VICEMAC_PATH_CAPACITY) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.unit = unit;
    request.drive = drive;
    request.run_mode = run_mode;
    vicemac_copy_cstring(request.path, sizeof(request.path), path);
    vicemac_copy_cstring(request.program_name,
                         sizeof(request.program_name),
                         program_name);

    if (pthread_mutex_init(&request.mutex, 0) != 0) {
        return 0;
    }
    if (pthread_cond_init(&request.condition, 0) != 0) {
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    if (!vicemac_drive_attach_request_queue_push(&request)) {
        pthread_cond_destroy(&request.condition);
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    pthread_mutex_lock(&request.mutex);
    while (!request.completed) {
        pthread_cond_wait(&request.condition, &request.mutex);
    }
    success = request.success;
    pthread_mutex_unlock(&request.mutex);

    pthread_cond_destroy(&request.condition);
    pthread_mutex_destroy(&request.mutex);
    return success;
}

int vicemac_queue_joystick_value(uint32_t port, uint32_t value)
{
    vicemac_joystick_event_t event;

    if (port >= JOYPORT_MAX_PORTS) {
        return 0;
    }

    event.port = port;
    event.value = value;

    return vicemac_queue_push(&joystick_queue_mutex,
                              joystick_queue,
                              sizeof(joystick_queue[0]),
                              VICEMAC_JOYSTICK_QUEUE_CAPACITY,
                              &joystick_queue_read,
                              &joystick_queue_write,
                              &event);
}

int vicemac_queue_mouse_move(float delta_x, float delta_y)
{
    vicemac_mouse_event_t event;

    if (delta_x == 0.0f && delta_y == 0.0f) {
        return 1;
    }

    memset(&event, 0, sizeof(event));
    event.type = VICEMAC_MOUSE_EVENT_MOVE;
    event.delta_x = delta_x;
    event.delta_y = delta_y;

    return vicemac_queue_push(&mouse_queue_mutex,
                              mouse_queue,
                              sizeof(mouse_queue[0]),
                              VICEMAC_MOUSE_QUEUE_CAPACITY,
                              &mouse_queue_read,
                              &mouse_queue_write,
                              &event);
}

int vicemac_queue_mouse_button(uint32_t button, int pressed)
{
    vicemac_mouse_event_t event;

    if (button > 4) {
        return 0;
    }

    memset(&event, 0, sizeof(event));
    event.type = VICEMAC_MOUSE_EVENT_BUTTON;
    event.button = button;
    event.pressed = pressed ? 1 : 0;

    return vicemac_queue_push(&mouse_queue_mutex,
                              mouse_queue,
                              sizeof(mouse_queue[0]),
                              VICEMAC_MOUSE_QUEUE_CAPACITY,
                              &mouse_queue_read,
                              &mouse_queue_write,
                              &event);
}

int vicemac_queue_mouse_reset(void)
{
    vicemac_mouse_event_t event;

    memset(&event, 0, sizeof(event));
    event.type = VICEMAC_MOUSE_EVENT_RESET;

    return vicemac_queue_push(&mouse_queue_mutex,
                              mouse_queue,
                              sizeof(mouse_queue[0]),
                              VICEMAC_MOUSE_QUEUE_CAPACITY,
                              &mouse_queue_read,
                              &mouse_queue_write,
                              &event);
}

static int vicemac_queue_machine_command(vicemac_machine_command_type_t type, int value)
{
    vicemac_machine_command_t command;

    command.type = type;
    command.value = value;

    return vicemac_queue_push(&machine_command_queue_mutex,
                              machine_command_queue,
                              sizeof(machine_command_queue[0]),
                              VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY,
                              &machine_command_queue_read,
                              &machine_command_queue_write,
                              &command);
}

int vicemac_queue_pause(int paused)
{
    return vicemac_queue_machine_command(VICEMAC_MACHINE_COMMAND_PAUSE,
                                         paused ? 1 : 0);
}

int vicemac_queue_system_time_sync(int enabled)
{
    return vicemac_queue_machine_command(VICEMAC_MACHINE_COMMAND_SYSTEM_TIME_SYNC,
                                         enabled ? 1 : 0);
}

int vicemac_queue_machine_model(const char *model)
{
    return vicemac_queue_resource_string(VICEMAC_MACHINE_MODEL_RESOURCE, model);
}

int vicemac_queue_machine_reset(uint32_t reset_mode)
{
    if (reset_mode != MACHINE_RESET_MODE_RESET_CPU
        && reset_mode != MACHINE_RESET_MODE_POWER_CYCLE) {
        return 0;
    }

    return vicemac_queue_machine_command(VICEMAC_MACHINE_COMMAND_RESET,
                                         (int)reset_mode);
}

int vicemac_queue_warp_mode(int enabled)
{
    return vicemac_queue_machine_command(VICEMAC_MACHINE_COMMAND_WARP,
                                         enabled ? 1 : 0);
}

int vicemac_queue_quit(void)
{
    return vicemac_queue_machine_command(VICEMAC_MACHINE_COMMAND_QUIT, 0);
}

int vicemac_queue_drive_reset(uint32_t unit)
{
    vicemac_drive_command_t command;

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_DRIVE_COMMAND_RESET;
    command.unit = unit;

    return vicemac_queue_push(&drive_command_queue_mutex,
                              drive_command_queue,
                              sizeof(drive_command_queue[0]),
                              VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY,
                              &drive_command_queue_read,
                              &drive_command_queue_write,
                              &command);
}

int vicemac_queue_drive_attach_disk_v2(uint32_t unit,
                                       uint32_t drive,
                                       const char *path,
                                       const char *program_name,
                                       int run_mode)
{
    return vicemac_perform_drive_attach_request(unit,
                                                drive,
                                                path,
                                                program_name,
                                                run_mode);
}

int vicemac_queue_drive_attach_disk(uint32_t unit,
                                    uint32_t drive,
                                    const char *path,
                                    int run_mode)
{
    return vicemac_queue_drive_attach_disk_v2(unit,
                                             drive,
                                             path,
                                             0,
                                             run_mode);
}

int vicemac_queue_drive_detach_disk(uint32_t unit, uint32_t drive)
{
    vicemac_drive_command_t command;

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_DRIVE_COMMAND_DETACH_DISK;
    command.unit = unit;
    command.drive = drive;

    return vicemac_queue_push(&drive_command_queue_mutex,
                              drive_command_queue,
                              sizeof(drive_command_queue[0]),
                              VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY,
                              &drive_command_queue_read,
                              &drive_command_queue_write,
                              &command);
}

int vicemac_queue_drive_sound_preview(uint32_t unit)
{
    vicemac_drive_command_t command;

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_DRIVE_COMMAND_PREVIEW_SOUND;
    command.unit = unit;

    return vicemac_queue_push(&drive_command_queue_mutex,
                              drive_command_queue,
                              sizeof(drive_command_queue[0]),
                              VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY,
                              &drive_command_queue_read,
                              &drive_command_queue_write,
                              &command);
}

int vicemac_queue_media_autostart(const char *path, int run_mode)
{
    vicemac_media_command_t command;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_MEDIA_COMMAND_AUTOSTART;
    command.run_mode = run_mode;
    vicemac_copy_cstring(command.path, sizeof(command.path), path);

    return vicemac_queue_push(&media_command_queue_mutex,
                              media_command_queue,
                              sizeof(media_command_queue[0]),
                              VICEMAC_MEDIA_COMMAND_QUEUE_CAPACITY,
                              &media_command_queue_read,
                              &media_command_queue_write,
                              &command);
}

int vicemac_queue_tape_attach(uint32_t unit, const char *path)
{
    vicemac_tape_command_t command;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_TAPE_COMMAND_ATTACH;
    command.unit = unit;
    vicemac_copy_cstring(command.path, sizeof(command.path), path);

    return vicemac_queue_push(&tape_command_queue_mutex,
                              tape_command_queue,
                              sizeof(tape_command_queue[0]),
                              VICEMAC_TAPE_COMMAND_QUEUE_CAPACITY,
                              &tape_command_queue_read,
                              &tape_command_queue_write,
                              &command);
}

int vicemac_queue_tape_detach(uint32_t unit)
{
    vicemac_tape_command_t command;

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_TAPE_COMMAND_DETACH;
    command.unit = unit;

    return vicemac_queue_push(&tape_command_queue_mutex,
                              tape_command_queue,
                              sizeof(tape_command_queue[0]),
                              VICEMAC_TAPE_COMMAND_QUEUE_CAPACITY,
                              &tape_command_queue_read,
                              &tape_command_queue_write,
                              &command);
}

int vicemac_queue_tape_control(uint32_t unit, int control)
{
    vicemac_tape_command_t command;

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_TAPE_COMMAND_CONTROL;
    command.unit = unit;
    command.control = control;

    return vicemac_queue_push(&tape_command_queue_mutex,
                              tape_command_queue,
                              sizeof(tape_command_queue[0]),
                              VICEMAC_TAPE_COMMAND_QUEUE_CAPACITY,
                              &tape_command_queue_read,
                              &tape_command_queue_write,
                              &command);
}

int vicemac_queue_cartridge_attach(const char *path)
{
    vicemac_cartridge_command_t command;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_CARTRIDGE_COMMAND_ATTACH;
    vicemac_copy_cstring(command.path, sizeof(command.path), path);

    return vicemac_queue_push(&cartridge_command_queue_mutex,
                              cartridge_command_queue,
                              sizeof(cartridge_command_queue[0]),
                              VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY,
                              &cartridge_command_queue_read,
                              &cartridge_command_queue_write,
                              &command);
}

int vicemac_queue_cartridge_detach(void)
{
    vicemac_cartridge_command_t command;

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_CARTRIDGE_COMMAND_DETACH;

    return vicemac_queue_push(&cartridge_command_queue_mutex,
                              cartridge_command_queue,
                              sizeof(cartridge_command_queue[0]),
                              VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY,
                              &cartridge_command_queue_read,
                              &cartridge_command_queue_write,
                              &command);
}

static int vicemac_perform_snapshot_request(vicemac_snapshot_request_type_t type,
                                            const char *path,
                                            int save_roms,
                                            int save_disks)
{
    vicemac_snapshot_request_t request;
    int success;

    if (path == 0 || path[0] == '\0' || strlen(path) >= sizeof(request.path)) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.type = type;
    request.save_roms = save_roms ? 1 : 0;
    request.save_disks = save_disks ? 1 : 0;
    vicemac_copy_cstring(request.path, sizeof(request.path), path);

    if (pthread_mutex_init(&request.mutex, 0) != 0) {
        return 0;
    }
    if (pthread_cond_init(&request.condition, 0) != 0) {
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    if (!vicemac_snapshot_queue_push(&request)) {
        pthread_cond_destroy(&request.condition);
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    pthread_mutex_lock(&request.mutex);
    while (!request.completed) {
        pthread_cond_wait(&request.condition, &request.mutex);
    }
    success = request.success;
    pthread_mutex_unlock(&request.mutex);

    pthread_cond_destroy(&request.condition);
    pthread_mutex_destroy(&request.mutex);
    return success;
}

int vicemac_save_snapshot(const char *path, int save_roms, int save_disks)
{
    return vicemac_perform_snapshot_request(VICEMAC_SNAPSHOT_REQUEST_SAVE,
                                            path,
                                            save_roms,
                                            save_disks);
}

int vicemac_load_snapshot(const char *path)
{
    return vicemac_perform_snapshot_request(VICEMAC_SNAPSHOT_REQUEST_LOAD,
                                            path,
                                            0,
                                            0);
}

static int vicemac_perform_memory_request(vicemac_memory_request_type_t type,
                                          uint32_t memspace,
                                          int32_t bank,
                                          uint32_t address,
                                          uint8_t *read_buffer,
                                          const uint8_t *write_bytes,
                                          uint32_t length)
{
    vicemac_memory_request_t request;
    int success;

    if (length == 0 || address > UINT16_MAX || length > (UINT32_MAX - address)
        || address + length > ((uint32_t)UINT16_MAX + 1U)) {
        return 0;
    }

    if ((type == VICEMAC_MEMORY_REQUEST_PEEK && read_buffer == 0)
        || (type == VICEMAC_MEMORY_REQUEST_POKE && write_bytes == 0)) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.type = type;
    request.memspace = memspace;
    request.bank = bank;
    request.address = address;
    request.length = length;
    request.read_buffer = read_buffer;
    request.write_bytes = write_bytes;

    if (pthread_mutex_init(&request.mutex, 0) != 0) {
        return 0;
    }
    if (pthread_cond_init(&request.condition, 0) != 0) {
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    if (!vicemac_memory_queue_push(&request)) {
        pthread_cond_destroy(&request.condition);
        pthread_mutex_destroy(&request.mutex);
        return 0;
    }

    pthread_mutex_lock(&request.mutex);
    while (!request.completed) {
        pthread_cond_wait(&request.condition, &request.mutex);
    }
    success = request.success;
    pthread_mutex_unlock(&request.mutex);

    pthread_cond_destroy(&request.condition);
    pthread_mutex_destroy(&request.mutex);
    return success;
}

int vicemac_peek_memory(uint32_t memspace,
                        int32_t bank,
                        uint32_t address,
                        uint8_t *buffer,
                        uint32_t length)
{
    return vicemac_perform_memory_request(VICEMAC_MEMORY_REQUEST_PEEK,
                                          memspace,
                                          bank,
                                          address,
                                          buffer,
                                          0,
                                          length);
}

int vicemac_poke_memory(uint32_t memspace,
                        int32_t bank,
                        uint32_t address,
                        const uint8_t *bytes,
                        uint32_t length)
{
    return vicemac_perform_memory_request(VICEMAC_MEMORY_REQUEST_POKE,
                                          memspace,
                                          bank,
                                          address,
                                          0,
                                          bytes,
                                          length);
}

static int vicemac_perform_debugger_request(vicemac_debugger_request_t *request)
{
    int success;

    if (request == 0) {
        return 0;
    }

    if (pthread_mutex_init(&request->mutex, 0) != 0) {
        return 0;
    }
    if (pthread_cond_init(&request->condition, 0) != 0) {
        pthread_mutex_destroy(&request->mutex);
        return 0;
    }

    if (!vicemac_debugger_queue_push(request)) {
        pthread_cond_destroy(&request->condition);
        pthread_mutex_destroy(&request->mutex);
        return 0;
    }

    pthread_mutex_lock(&request->mutex);
    while (!request->completed) {
        pthread_cond_wait(&request->condition, &request->mutex);
    }
    success = request->success;
    pthread_mutex_unlock(&request->mutex);

    pthread_cond_destroy(&request->condition);
    pthread_mutex_destroy(&request->mutex);
    return success;
}

int vicemac_debugger_snapshot(uint32_t memspace,
                              vicemac_debugger_snapshot_t *snapshot)
{
    vicemac_debugger_request_t request;

    if (snapshot == 0) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_SNAPSHOT;
    request.memspace = memspace;
    request.snapshot = snapshot;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_disassemble(uint32_t memspace,
                                 int32_t bank,
                                 uint32_t address,
                                 vicemac_debugger_disassembly_line_t *lines,
                                 uint32_t capacity,
                                 uint32_t *count)
{
    vicemac_debugger_request_t request;

    if (lines == 0 || count == 0 || capacity == 0 || address > UINT16_MAX) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_DISASSEMBLE;
    request.memspace = memspace;
    request.bank = bank;
    request.address = address;
    request.disassembly_lines = lines;
    request.capacity = capacity;
    request.output_count = count;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_list_checkpoints(vicemac_debugger_checkpoint_t *checkpoints,
                                      uint32_t capacity,
                                      uint32_t *count)
{
    vicemac_debugger_request_t request;

    if (checkpoints == 0 || count == 0 || capacity == 0) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_LIST_CHECKPOINTS;
    request.checkpoints = checkpoints;
    request.capacity = capacity;
    request.output_count = count;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_set_checkpoint(uint32_t memspace,
                                    uint32_t start_address,
                                    uint32_t end_address,
                                    uint32_t operations,
                                    int stops,
                                    int enabled,
                                    int temporary,
                                    uint32_t *checkpoint_id)
{
    vicemac_debugger_request_t request;

    if (checkpoint_id == 0 || start_address > UINT16_MAX || end_address > UINT16_MAX
        || start_address > end_address || (operations & (e_load | e_store | e_exec)) == 0) {
        return 0;
    }

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_SET_CHECKPOINT;
    request.memspace = memspace;
    request.address = start_address;
    request.end_address = end_address;
    request.operations = operations;
    request.stops = stops ? 1 : 0;
    request.enabled = enabled ? 1 : 0;
    request.temporary = temporary ? 1 : 0;
    request.output_id = checkpoint_id;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_delete_checkpoint(uint32_t checkpoint_id)
{
    vicemac_debugger_request_t request;

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_DELETE_CHECKPOINT;
    request.checkpoint_id = checkpoint_id;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_set_checkpoint_enabled(uint32_t checkpoint_id, int enabled)
{
    vicemac_debugger_request_t request;

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_SET_CHECKPOINT_ENABLED;
    request.checkpoint_id = checkpoint_id;
    request.enabled = enabled ? 1 : 0;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_set_register(uint32_t memspace,
                                  uint32_t register_id,
                                  uint32_t value)
{
    vicemac_debugger_request_t request;

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_SET_REGISTER;
    request.memspace = memspace;
    request.register_id = register_id;
    request.value = value;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_set_cpu(uint32_t memspace, uint32_t cpu_type)
{
    vicemac_debugger_request_t request;

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_SET_CPU;
    request.memspace = memspace;
    request.cpu_type = cpu_type;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_step(uint32_t count, int step_over)
{
    vicemac_debugger_request_t request;

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_STEP;
    request.count = count == 0 ? 1 : count;
    request.step_over = step_over ? 1 : 0;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_return(void)
{
    vicemac_debugger_request_t request;

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_RETURN;
    return vicemac_perform_debugger_request(&request);
}

int vicemac_debugger_continue(void)
{
    vicemac_debugger_request_t request;

    memset(&request, 0, sizeof(request));
    request.type = VICEMAC_DEBUGGER_REQUEST_CONTINUE;
    return vicemac_perform_debugger_request(&request);
}

static int vicemac_pop_key_event(vicemac_input_event_t *event)
{
    return vicemac_queue_pop(&input_queue_mutex,
                             input_queue,
                             sizeof(input_queue[0]),
                             VICEMAC_INPUT_QUEUE_CAPACITY,
                             &input_queue_read,
                             &input_queue_write,
                             event);
}

static int vicemac_pop_keyboard_text_event(vicemac_keyboard_text_event_t *event)
{
    return vicemac_queue_pop(&keyboard_text_queue_mutex,
                             keyboard_text_queue,
                             sizeof(keyboard_text_queue[0]),
                             VICEMAC_KEYBOARD_TEXT_QUEUE_CAPACITY,
                             &keyboard_text_queue_read,
                             &keyboard_text_queue_write,
                             event);
}

static void vicemac_basic_text_to_petscii(char *text)
{
    char *read = text;
    char *write = text;

    while (*read != '\0') {
        unsigned char c = (unsigned char)*read;

        if (c == '\r') {
            *write++ = 0x0d;
            read++;
            if (*read == '\n') {
                read++;
            }
        } else if (c == '\n') {
            *write++ = 0x0d;
            read++;
        } else if (c >= 'a' && c <= 'z') {
            *write++ = (char)(c - ('a' - 'A'));
            read++;
        } else if (c >= 'A' && c <= 'Z') {
            *write++ = (char)c;
            read++;
        } else if (c == '`') {
            *write++ = '\'';
            read++;
        } else if (c >= 0x20 && c <= 0x5f) {
            *write++ = (char)c;
            read++;
        } else {
            *write++ = '?';
            read++;
        }
    }

    *write = '\0';
}

static int vicemac_pop_resource_int_event(vicemac_resource_int_event_t *event)
{
    return vicemac_queue_pop(&resource_queue_mutex,
                             resource_queue,
                             sizeof(resource_queue[0]),
                             VICEMAC_RESOURCE_QUEUE_CAPACITY,
                             &resource_queue_read,
                             &resource_queue_write,
                             event);
}

static int vicemac_pop_resource_string_event(vicemac_resource_string_event_t *event)
{
    return vicemac_queue_pop(&resource_string_queue_mutex,
                             resource_string_queue,
                             sizeof(resource_string_queue[0]),
                             VICEMAC_RESOURCE_QUEUE_CAPACITY,
                             &resource_string_queue_read,
                             &resource_string_queue_write,
                             event);
}

static int vicemac_pop_joystick_event(vicemac_joystick_event_t *event)
{
    return vicemac_queue_pop(&joystick_queue_mutex,
                             joystick_queue,
                             sizeof(joystick_queue[0]),
                             VICEMAC_JOYSTICK_QUEUE_CAPACITY,
                             &joystick_queue_read,
                             &joystick_queue_write,
                             event);
}

static int vicemac_pop_mouse_event(vicemac_mouse_event_t *event)
{
    return vicemac_queue_pop(&mouse_queue_mutex,
                             mouse_queue,
                             sizeof(mouse_queue[0]),
                             VICEMAC_MOUSE_QUEUE_CAPACITY,
                             &mouse_queue_read,
                             &mouse_queue_write,
                             event);
}

static int vicemac_pop_machine_command(vicemac_machine_command_t *command)
{
    return vicemac_queue_pop(&machine_command_queue_mutex,
                             machine_command_queue,
                             sizeof(machine_command_queue[0]),
                             VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY,
                             &machine_command_queue_read,
                             &machine_command_queue_write,
                             command);
}

static int vicemac_pop_drive_command(vicemac_drive_command_t *command)
{
    return vicemac_queue_pop(&drive_command_queue_mutex,
                             drive_command_queue,
                             sizeof(drive_command_queue[0]),
                             VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY,
                             &drive_command_queue_read,
                             &drive_command_queue_write,
                             command);
}

static int vicemac_pop_drive_attach_request(vicemac_drive_attach_request_t **request)
{
    return vicemac_drive_attach_request_queue_pop(request);
}

static int vicemac_pop_media_command(vicemac_media_command_t *command)
{
    return vicemac_queue_pop(&media_command_queue_mutex,
                             media_command_queue,
                             sizeof(media_command_queue[0]),
                             VICEMAC_MEDIA_COMMAND_QUEUE_CAPACITY,
                             &media_command_queue_read,
                             &media_command_queue_write,
                             command);
}

static int vicemac_pop_tape_command(vicemac_tape_command_t *command)
{
    return vicemac_queue_pop(&tape_command_queue_mutex,
                             tape_command_queue,
                             sizeof(tape_command_queue[0]),
                             VICEMAC_TAPE_COMMAND_QUEUE_CAPACITY,
                             &tape_command_queue_read,
                             &tape_command_queue_write,
                             command);
}

static int vicemac_pop_cartridge_command(vicemac_cartridge_command_t *command)
{
    return vicemac_queue_pop(&cartridge_command_queue_mutex,
                             cartridge_command_queue,
                             sizeof(cartridge_command_queue[0]),
                             VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY,
                             &cartridge_command_queue_read,
                             &cartridge_command_queue_write,
                             command);
}

static MEMSPACE vicemac_normalized_memspace(uint32_t memspace)
{
    if (memspace == e_default_space) {
        return e_comp_space;
    }

    return (MEMSPACE)memspace;
}

static int vicemac_memory_request_bank(MEMSPACE memspace, int32_t requested_bank, int *bank)
{
    if (memspace <= e_default_space || memspace >= e_invalid_space
        || mon_interfaces[memspace] == 0 || bank == 0) {
        return 0;
    }

    if (requested_bank == VICEMAC_CURRENT_MEMORY_BANK) {
        *bank = mon_interfaces[memspace]->current_bank;
        return 1;
    }

    if (requested_bank < 0 || mon_banknum_validate(memspace, (int)requested_bank) == 0) {
        return 0;
    }

    *bank = (int)requested_bank;
    return 1;
}

static int vicemac_debugger_valid_memspace(MEMSPACE memspace)
{
    return memspace > e_default_space
        && memspace < e_invalid_space
        && mon_interfaces[memspace] != 0
        && monitor_cpu_for_memspace[memspace] != 0;
}

static int vicemac_debugger_fill_snapshot(vicemac_debugger_request_t *request)
{
    vicemac_debugger_snapshot_t *snapshot;
    monitor_cpu_type_t *monitor_cpu;
    mon_reg_list_t *registers;
    mon_reg_list_t *current_register;
    supported_cpu_type_list_t *supported_cpu;
    MEMSPACE memspace;
    int bank;
    uint32_t register_count = 0;
    uint32_t cpu_count = 0;

    if (request == 0 || request->snapshot == 0) {
        return 0;
    }

    snapshot = request->snapshot;
    memset(snapshot, 0, sizeof(*snapshot));

    memspace = vicemac_normalized_memspace(request->memspace);
    if (!vicemac_debugger_valid_memspace(memspace)
        || !vicemac_memory_request_bank(memspace, VICEMAC_CURRENT_MEMORY_BANK, &bank)) {
        return 0;
    }

    monitor_cpu = monitor_cpu_for_memspace[memspace];
    snapshot->valid = 1;
    snapshot->memspace = (uint32_t)memspace;
    snapshot->cpu_type = (uint32_t)monitor_cpu->cpu_type;
    snapshot->bank = bank;
    snapshot->cycle = mon_interfaces[memspace]->clk != 0 ? (uint64_t)*mon_interfaces[memspace]->clk : 0;
    snapshot->program_counter = monitor_cpu->mon_register_get_val != 0
        ? monitor_cpu->mon_register_get_val((int)memspace, e_PC)
        : 0;

    supported_cpu = monitor_cpu_type_supported[memspace];
    while (supported_cpu != 0 && cpu_count < VICEMAC_DEBUGGER_MAX_CPUS) {
        if (supported_cpu->monitor_cpu_type_p != 0) {
            snapshot->supported_cpu_types[cpu_count] =
                (uint32_t)supported_cpu->monitor_cpu_type_p->cpu_type;
            cpu_count++;
        }
        supported_cpu = supported_cpu->next;
    }
    snapshot->supported_cpu_count = cpu_count;

    registers = mon_register_list_get((int)memspace);
    if (registers == 0) {
        return 1;
    }

    current_register = registers;
    while (current_register->name != 0 && register_count < VICEMAC_DEBUGGER_MAX_REGISTERS) {
        vicemac_debugger_register_t *target = &snapshot->registers[register_count];
        target->id = current_register->id;
        target->bit_width = current_register->size;
        target->flags = current_register->flags;
        target->extra = current_register->extra;
        target->value = current_register->val;
        vicemac_copy_cstring(target->name, sizeof(target->name), current_register->name);
        register_count++;
        current_register++;
    }

    snapshot->register_count = register_count;
    lib_free(registers);
    return 1;
}

static int vicemac_debugger_disassemble_request(vicemac_debugger_request_t *request)
{
    monitor_interface_t *interface;
    MEMSPACE memspace;
    uint32_t line_index;
    uint16_t current_address;
    int bank;

    if (request == 0 || request->disassembly_lines == 0
        || request->output_count == 0 || request->capacity == 0
        || request->address > UINT16_MAX) {
        return 0;
    }

    memspace = vicemac_normalized_memspace(request->memspace);
    if (!vicemac_debugger_valid_memspace(memspace)
        || !vicemac_memory_request_bank(memspace, request->bank, &bank)) {
        return 0;
    }

    interface = mon_interfaces[memspace];
    if (interface->mem_bank_peek == 0) {
        return 0;
    }

    current_address = (uint16_t)request->address;
    *request->output_count = 0;

    for (line_index = 0; line_index < request->capacity; line_index++) {
        vicemac_debugger_disassembly_line_t *line = &request->disassembly_lines[line_index];
        const char *text;
        unsigned int line_size = 1;

        memset(line, 0, sizeof(*line));
        line->address = current_address;
        line->bytes[0] = interface->mem_bank_peek(bank, current_address, interface->context);
        line->bytes[1] = interface->mem_bank_peek(bank, (uint16_t)(current_address + 1U), interface->context);
        line->bytes[2] = interface->mem_bank_peek(bank, (uint16_t)(current_address + 2U), interface->context);
        line->bytes[3] = interface->mem_bank_peek(bank, (uint16_t)(current_address + 3U), interface->context);

        text = mon_disassemble_to_string_ex(memspace,
                                            current_address,
                                            line->bytes[0],
                                            line->bytes[1],
                                            line->bytes[2],
                                            line->bytes[3],
                                            1,
                                            &line_size);
        if (line_size == 0 || line_size > sizeof(line->bytes)) {
            line_size = 1;
        }
        line->size = line_size;
        vicemac_copy_cstring(line->text, sizeof(line->text), text);

        current_address = (uint16_t)(current_address + line_size);
        *request->output_count = line_index + 1U;
    }

    return 1;
}

static void vicemac_debugger_fill_checkpoint(vicemac_debugger_checkpoint_t *target,
                                             const mon_checkpoint_t *source)
{
    target->id = (uint32_t)source->checknum;
    target->memspace = (uint32_t)addr_memspace(source->start_addr);
    target->start_address = addr_location(source->start_addr) & UINT16_MAX;
    target->end_address = addr_location(source->end_addr) & UINT16_MAX;
    target->operations = (source->check_load ? e_load : 0)
        | (source->check_store ? e_store : 0)
        | (source->check_exec ? e_exec : 0);
    target->enabled = source->enabled ? 1U : 0U;
    target->stops = source->stop ? 1U : 0U;
    target->temporary = source->temporary ? 1U : 0U;
    target->hit_count = source->hit_count < 0 ? 0U : (uint32_t)source->hit_count;
    target->ignore_count = source->ignore_count < 0 ? 0U : (uint32_t)source->ignore_count;
}

static int vicemac_debugger_list_checkpoints_request(vicemac_debugger_request_t *request)
{
    mon_checkpoint_t **checkpoint_list;
    unsigned int checkpoint_count = 0;
    uint32_t index;
    uint32_t visible_count;

    if (request == 0 || request->checkpoints == 0
        || request->output_count == 0 || request->capacity == 0) {
        return 0;
    }

    checkpoint_list = mon_breakpoint_checkpoint_list_get(&checkpoint_count);
    if (checkpoint_list == 0) {
        *request->output_count = 0;
        return 1;
    }

    visible_count = checkpoint_count < request->capacity ? checkpoint_count : request->capacity;
    for (index = 0; index < visible_count; index++) {
        if (checkpoint_list[index] != 0) {
            vicemac_debugger_fill_checkpoint(&request->checkpoints[index], checkpoint_list[index]);
        }
    }

    *request->output_count = visible_count;
    lib_free(checkpoint_list);
    return 1;
}

static int vicemac_debugger_set_checkpoint_request(vicemac_debugger_request_t *request)
{
    MEMSPACE memspace;
    MEMORY_OP operations;
    int checknum;

    if (request == 0 || request->output_id == 0
        || request->address > UINT16_MAX || request->end_address > UINT16_MAX
        || request->address > request->end_address) {
        return 0;
    }

    memspace = vicemac_normalized_memspace(request->memspace);
    if (!vicemac_debugger_valid_memspace(memspace)) {
        return 0;
    }

    operations = (MEMORY_OP)(request->operations & (e_load | e_store | e_exec));
    if (operations == 0) {
        return 0;
    }

    checknum = mon_breakpoint_add_checkpoint(new_addr(memspace, request->address),
                                             new_addr(memspace, request->end_address),
                                             request->stops != 0,
                                             operations,
                                             request->temporary != 0,
                                             FALSE);
    if (checknum <= 0) {
        return 0;
    }

    if (!request->enabled) {
        mon_breakpoint_switch_checkpoint(e_OFF, checknum);
    }

    *request->output_id = (uint32_t)checknum;
    return 1;
}

static int vicemac_debugger_delete_checkpoint_request(vicemac_debugger_request_t *request)
{
    if (request == 0 || mon_breakpoint_find_checkpoint((int)request->checkpoint_id) == 0) {
        return 0;
    }

    mon_breakpoint_delete_checkpoint((int)request->checkpoint_id);
    return 1;
}

static int vicemac_debugger_set_checkpoint_enabled_request(vicemac_debugger_request_t *request)
{
    if (request == 0 || mon_breakpoint_find_checkpoint((int)request->checkpoint_id) == 0) {
        return 0;
    }

    mon_breakpoint_switch_checkpoint(request->enabled ? e_ON : e_OFF,
                                     (int)request->checkpoint_id);
    return 1;
}

static int vicemac_debugger_set_register_request(vicemac_debugger_request_t *request)
{
    monitor_cpu_type_t *monitor_cpu;
    MEMSPACE memspace;

    if (request == 0) {
        return 0;
    }

    memspace = vicemac_normalized_memspace(request->memspace);
    if (!vicemac_debugger_valid_memspace(memspace)
        || !mon_register_valid((int)memspace, (int)request->register_id)) {
        return 0;
    }

    monitor_cpu = monitor_cpu_for_memspace[memspace];
    if (monitor_cpu->mon_register_set_val == 0) {
        return 0;
    }

    monitor_cpu->mon_register_set_val((int)memspace,
                                      (int)request->register_id,
                                      (uint16_t)request->value);
    return 1;
}

static int vicemac_debugger_set_cpu_request(vicemac_debugger_request_t *request)
{
    supported_cpu_type_list_t *supported_cpu;
    MEMSPACE memspace;

    if (request == 0) {
        return 0;
    }

    memspace = vicemac_normalized_memspace(request->memspace);
    if (!vicemac_debugger_valid_memspace(memspace)) {
        return 0;
    }

    supported_cpu = monitor_cpu_type_supported[memspace];
    while (supported_cpu != 0) {
        if (supported_cpu->monitor_cpu_type_p != 0
            && (uint32_t)supported_cpu->monitor_cpu_type_p->cpu_type == request->cpu_type) {
            monitor_cpu_for_memspace[memspace] = supported_cpu->monitor_cpu_type_p;
            return 1;
        }
        supported_cpu = supported_cpu->next;
    }

    return 0;
}

static int vicemac_dispatch_debugger_request(vicemac_debugger_request_t *request)
{
    if (request == 0) {
        return 0;
    }

    switch (request->type) {
        case VICEMAC_DEBUGGER_REQUEST_SNAPSHOT:
            return vicemac_debugger_fill_snapshot(request);
        case VICEMAC_DEBUGGER_REQUEST_DISASSEMBLE:
            return vicemac_debugger_disassemble_request(request);
        case VICEMAC_DEBUGGER_REQUEST_LIST_CHECKPOINTS:
            return vicemac_debugger_list_checkpoints_request(request);
        case VICEMAC_DEBUGGER_REQUEST_SET_CHECKPOINT:
            return vicemac_debugger_set_checkpoint_request(request);
        case VICEMAC_DEBUGGER_REQUEST_DELETE_CHECKPOINT:
            return vicemac_debugger_delete_checkpoint_request(request);
        case VICEMAC_DEBUGGER_REQUEST_SET_CHECKPOINT_ENABLED:
            return vicemac_debugger_set_checkpoint_enabled_request(request);
        case VICEMAC_DEBUGGER_REQUEST_SET_REGISTER:
            return vicemac_debugger_set_register_request(request);
        case VICEMAC_DEBUGGER_REQUEST_SET_CPU:
            return vicemac_debugger_set_cpu_request(request);
        case VICEMAC_DEBUGGER_REQUEST_STEP:
            if (request->step_over) {
                mon_instructions_next((int)request->count);
            } else {
                mon_instructions_step((int)request->count);
            }
            return 1;
        case VICEMAC_DEBUGGER_REQUEST_RETURN:
            mon_instruction_return();
            return 1;
        case VICEMAC_DEBUGGER_REQUEST_CONTINUE:
            mon_go();
            return 1;
    }

    return 0;
}

static void vicemac_dispatch_queued_debugger_requests(void)
{
    vicemac_debugger_request_t *request;

    while (vicemac_debugger_queue_pop(&request)) {
        vicemac_complete_debugger_request(request,
                                          vicemac_dispatch_debugger_request(request));
    }
}

static int vicemac_dispatch_memory_request(vicemac_memory_request_t *request)
{
    monitor_interface_t *interface;
    MEMSPACE memspace;
    uint32_t index;
    int bank;
    int drive_number;

    if (request == 0 || request->length == 0 || request->address > UINT16_MAX
        || request->address + request->length > ((uint32_t)UINT16_MAX + 1U)) {
        return 0;
    }

    memspace = vicemac_normalized_memspace(request->memspace);
    if (!vicemac_memory_request_bank(memspace, request->bank, &bank)) {
        return 0;
    }
    interface = mon_interfaces[memspace];

    drive_number = monitor_diskspace_dnr(memspace);
    if (drive_number >= 0 && !check_drive_emu_level_ok(drive_number + 8)) {
        return 0;
    }

    switch (request->type) {
        case VICEMAC_MEMORY_REQUEST_PEEK:
            if (request->read_buffer == 0 || interface->mem_bank_peek == 0) {
                return 0;
            }
            for (index = 0; index < request->length; index++) {
                request->read_buffer[index] = interface->mem_bank_peek(bank,
                                                                       (uint16_t)(request->address + index),
                                                                       interface->context);
            }
            return 1;
        case VICEMAC_MEMORY_REQUEST_POKE:
            if (request->write_bytes == 0 || interface->mem_bank_poke == 0) {
                return 0;
            } else {
                for (index = 0; index < request->length; index++) {
                    interface->mem_bank_poke(bank,
                                             (uint16_t)(request->address + index),
                                             request->write_bytes[index],
                                             interface->context);
                }
            }
            return 1;
    }

    return 0;
}

static void vicemac_dispatch_queued_memory_requests(void)
{
    vicemac_memory_request_t *request;

    while (vicemac_memory_queue_pop(&request)) {
        vicemac_complete_memory_request(request,
                                        vicemac_dispatch_memory_request(request));
    }
}

static int vicemac_dispatch_snapshot_request(vicemac_snapshot_request_t *request)
{
    if (request == 0 || request->path[0] == '\0') {
        return 0;
    }

    switch (request->type) {
        case VICEMAC_SNAPSHOT_REQUEST_SAVE:
            return machine_write_snapshot(request->path,
                                          request->save_roms,
                                          request->save_disks,
                                          0) >= 0;
        case VICEMAC_SNAPSHOT_REQUEST_LOAD:
            if (machine_read_snapshot(request->path, 0) < 0) {
                return 0;
            }
            vicemac_publish_current_cartridge_status();
            return 1;
    }

    return 0;
}

static void vicemac_dispatch_queued_snapshot_requests(void)
{
    vicemac_snapshot_request_t *request;

    while (vicemac_snapshot_queue_pop(&request)) {
        vicemac_complete_snapshot_request(request,
                                          vicemac_dispatch_snapshot_request(request));
    }
}

static int vicemac_c64_model_for_name(const char *model)
{
    if (strcmp(model, "c64") == 0 || strcmp(model, "c64pal") == 0) {
        return C64MODEL_C64_PAL;
    }
    if (strcmp(model, "c64ntsc") == 0) {
        return C64MODEL_C64_NTSC;
    }
    if (strcmp(model, "c64c") == 0 || strcmp(model, "c64cpal") == 0) {
        return C64MODEL_C64C_PAL;
    }
    if (strcmp(model, "c64cntsc") == 0) {
        return C64MODEL_C64C_NTSC;
    }
    if (strcmp(model, "c64old") == 0 || strcmp(model, "c64oldpal") == 0) {
        return C64MODEL_C64_OLD_PAL;
    }
    if (strcmp(model, "c64oldntsc") == 0) {
        return C64MODEL_C64_OLD_NTSC;
    }
    if (strcmp(model, "sx64") == 0 || strcmp(model, "sx64pal") == 0) {
        return C64MODEL_C64SX_PAL;
    }
    if (strcmp(model, "sx64ntsc") == 0) {
        return C64MODEL_C64SX_NTSC;
    }

    return C64MODEL_UNKNOWN;
}

static int vicemac_c128_model_for_name(const char *model)
{
    if (strcmp(model, "c128") == 0 || strcmp(model, "c128pal") == 0) {
        return C128MODEL_C128_PAL;
    }
    if (strcmp(model, "c128ntsc") == 0) {
        return C128MODEL_C128_NTSC;
    }
    if (strcmp(model, "c128d") == 0 || strcmp(model, "c128dpal") == 0) {
        return C128MODEL_C128D_PAL;
    }
    if (strcmp(model, "c128dntsc") == 0) {
        return C128MODEL_C128D_NTSC;
    }
    if (strcmp(model, "c128dcr") == 0 || strcmp(model, "c128dcrpal") == 0) {
        return C128MODEL_C128DCR_PAL;
    }
    if (strcmp(model, "c128dcrntsc") == 0) {
        return C128MODEL_C128DCR_NTSC;
    }

    return C128MODEL_UNKNOWN;
}

static int vicemac_plus4_model_for_name(const char *model)
{
    if (strcmp(model, "c16") == 0 || strcmp(model, "c16pal") == 0) {
        return VICEMAC_PLUS4MODEL_C16_PAL;
    }
    if (strcmp(model, "c16ntsc") == 0) {
        return VICEMAC_PLUS4MODEL_C16_NTSC;
    }
    if (strcmp(model, "plus4") == 0 || strcmp(model, "plus4pal") == 0) {
        return VICEMAC_PLUS4MODEL_PLUS4_PAL;
    }
    if (strcmp(model, "plus4ntsc") == 0) {
        return VICEMAC_PLUS4MODEL_PLUS4_NTSC;
    }
    if (strcmp(model, "v364") == 0 || strcmp(model, "cv364") == 0) {
        return VICEMAC_PLUS4MODEL_V364_NTSC;
    }
    if (strcmp(model, "c232") == 0) {
        return VICEMAC_PLUS4MODEL_232_NTSC;
    }

    return VICEMAC_PLUS4MODEL_UNKNOWN;
}

static int vicemac_dispatch_integer_machine_model(const char *symbol_name, int model)
{
    typedef void (*machine_model_set_function_t)(int model);
    machine_model_set_function_t set_model_function;

    set_model_function = (machine_model_set_function_t)dlsym(RTLD_SELF, symbol_name);
    if (set_model_function == 0) {
        return 0;
    }

    set_model_function(model);
    return 1;
}

static int vicemac_dispatch_plus4_machine_model(int model)
{
    int sound_enabled = 0;
    int should_restore_sound = resources_get_int("Sound", &sound_enabled) == 0 && sound_enabled != 0;
    int did_set_model;

    if (should_restore_sound) {
        (void)resources_set_int("Sound", 0);
    }

    did_set_model = vicemac_dispatch_integer_machine_model("plus4model_set", model);

    if (should_restore_sound) {
        (void)resources_set_int("Sound", sound_enabled);
    }

    return did_set_model;
}

static int vicemac_dispatch_machine_model(const char *model)
{
    typedef int (*pet_set_model_function_t)(const char *model_name, void *extra);
    static pet_set_model_function_t pet_set_model_function = 0;
    static int did_lookup_pet_set_model = 0;
    int machine_model;

    machine_model = vicemac_c64_model_for_name(model);
    if (machine_model != C64MODEL_UNKNOWN
        && vicemac_dispatch_integer_machine_model("c64model_set", machine_model)) {
        return 1;
    }

    machine_model = vicemac_c128_model_for_name(model);
    if (machine_model != C128MODEL_UNKNOWN
        && vicemac_dispatch_integer_machine_model("c128model_set", machine_model)) {
        return 1;
    }

    machine_model = vicemac_plus4_model_for_name(model);
    if (machine_model != VICEMAC_PLUS4MODEL_UNKNOWN
        && vicemac_dispatch_plus4_machine_model(machine_model)) {
        return 1;
    }

    if (!did_lookup_pet_set_model) {
        pet_set_model_function = (pet_set_model_function_t)dlsym(RTLD_SELF, "pet_set_model");
        did_lookup_pet_set_model = 1;
    }

    return pet_set_model_function != 0 && pet_set_model_function(model, 0) == 0;
}

static void vicemac_dispatch_queued_resources(void)
{
    vicemac_resource_int_event_t int_event;
    vicemac_resource_string_event_t string_event;

    while (vicemac_pop_resource_int_event(&int_event)) {
        (void)resources_set_int(int_event.name, int_event.value);
    }

    while (vicemac_pop_resource_string_event(&string_event)) {
        if (strcmp(string_event.name, VICEMAC_MACHINE_MODEL_RESOURCE) == 0) {
            (void)vicemac_dispatch_machine_model(string_event.value);
        } else {
            (void)resources_set_string(string_event.name, string_event.value);
        }
    }
}

static int vicemac_dispatch_resource_request(vicemac_resource_request_t *request)
{
    const char *string_value = 0;

    if (request == 0 || request->name[0] == '\0') {
        return 0;
    }

    switch (request->type) {
        case VICEMAC_RESOURCE_REQUEST_INT:
            return resources_get_int(request->name, &request->int_value) == 0;
        case VICEMAC_RESOURCE_REQUEST_STRING:
            if (request->string_buffer == 0 || request->string_buffer_capacity == 0
                || resources_get_string(request->name, &string_value) < 0) {
                return 0;
            }
            vicemac_copy_cstring(request->string_buffer,
                                 request->string_buffer_capacity,
                                 string_value != 0 ? string_value : "");
            return 1;
    }

    return 0;
}

static void vicemac_dispatch_queued_resource_requests(void)
{
    vicemac_resource_request_t *request;

    while (vicemac_resource_request_queue_pop(&request)) {
        vicemac_complete_resource_request(request,
                                          vicemac_dispatch_resource_request(request));
    }
}

static void vicemac_dispatch_queued_input(void)
{
    vicemac_input_event_t event;
    vicemac_keyboard_text_event_t text_event;

    while (vicemac_pop_key_event(&event)) {
        if (event.clear) {
            keyboard_key_clear();
        } else if (event.pressed) {
            keyboard_key_pressed(event.key, event.mod);
        } else {
            keyboard_key_released(event.key, event.mod);
        }
    }

    while (vicemac_pop_keyboard_text_event(&text_event)) {
        char text[VICEMAC_KEYBOARD_TEXT_CAPACITY];

        vicemac_copy_cstring(text, sizeof(text), text_event.text);
        vicemac_basic_text_to_petscii(text);
        (void)kbdbuf_feed(text);
    }
}

static void vicemac_dispatch_queued_joystick_events(void)
{
    vicemac_joystick_event_t event;

    while (vicemac_pop_joystick_event(&event)) {
        if (event.port < JOYPORT_MAX_PORTS) {
            joystick_set_value_absolute((int)event.port, (uint16_t)(event.value & 0x0fffU));
        }
    }
}

static void vicemac_dispatch_queued_mouse_events(void)
{
    vicemac_mouse_event_t event;

    while (vicemac_pop_mouse_event(&event)) {
        switch (event.type) {
            case VICEMAC_MOUSE_EVENT_MOVE:
                mouse_move(event.delta_x, event.delta_y);
                break;
            case VICEMAC_MOUSE_EVENT_BUTTON:
                mouse_button((int)event.button, event.pressed);
                break;
            case VICEMAC_MOUSE_EVENT_RESET:
                mouse_reset();
                break;
        }
    }
}

typedef void (*vicemac_userport_rtc_sync_fn)(void);

static void vicemac_sync_userport_rtc_system_time(void)
{
    static vicemac_userport_rtc_sync_fn sync_fn = 0;
    static int did_resolve_sync_fn = 0;

    if (!did_resolve_sync_fn) {
        sync_fn = (vicemac_userport_rtc_sync_fn)dlsym(RTLD_SELF,
                                                      "userport_rtc_ds1307_sync_system_time");
        did_resolve_sync_fn = 1;
    }

    if (sync_fn != 0) {
        sync_fn();
    }
}

static void vicemac_dispatch_machine_command(vicemac_machine_command_t *command)
{
    switch (command->type) {
        case VICEMAC_MACHINE_COMMAND_PAUSE:
            if (command->value) {
                ui_pause_enable();
            } else {
                ui_pause_disable();
            }
            break;
        case VICEMAC_MACHINE_COMMAND_SYSTEM_TIME_SYNC:
            if (command->value) {
                (void)resources_set_int("UserportRTCDS1307Save", 0);
                if (resources_set_int("UserportDevice", USERPORT_DEVICE_RTC_DS1307) >= 0) {
                    vicemac_sync_userport_rtc_system_time();
                }
            } else if (userport_get_device() == USERPORT_DEVICE_RTC_DS1307) {
                (void)resources_set_int("UserportDevice", USERPORT_DEVICE_NONE);
            }
            break;
        case VICEMAC_MACHINE_COMMAND_RESET:
            vsync_suspend_speed_eval();
            machine_trigger_reset((unsigned int)command->value);
            ui_pause_disable();
            break;
        case VICEMAC_MACHINE_COMMAND_WARP:
            vsync_set_warp_mode(command->value);
            break;
        case VICEMAC_MACHINE_COMMAND_QUIT:
#ifdef USE_VICE_THREAD
            mainlock_initiate_shutdown();
#else
            main_exit();
            pthread_exit(NULL);
#endif
            break;
    }
}

static void vicemac_dispatch_queued_machine_commands(void)
{
    vicemac_machine_command_t command;

    while (vicemac_pop_machine_command(&command)) {
        vicemac_dispatch_machine_command(&command);
    }
}

static int vicemac_drive_unit_is_valid(uint32_t unit)
{
    return unit >= DRIVE_UNIT_MIN && unit <= DRIVE_UNIT_MAX;
}

static int vicemac_dispatch_drive_attach_disk(uint32_t unit,
                                              uint32_t drive,
                                              const char *path,
                                              const char *program_name,
                                              int run_mode)
{
    int result;
    const char *current_image;

    if (!vicemac_drive_unit_is_valid(unit) || drive >= NUM_DRIVES) {
        return -1;
    }

    if (run_mode != AUTOSTART_MODE_NONE) {
        result = autostart_disk((int)unit,
                                (int)drive,
                                path,
                                program_name != 0 && program_name[0] != '\0'
                                ? program_name
                                : 0,
                                0,
                                run_mode);
    } else {
        result = file_system_attach_disk(unit, drive, path);
    }

    current_image = file_system_get_disk_name(unit, drive);
    if (result < 0) {
        log_error(LOG_DEFAULT,
                  "VICE Mac: failed to attach disk unit %u:%u path `%s' run mode %d.",
                  unit,
                  drive,
                  path,
                  run_mode);
    } else {
        log_message(LOG_DEFAULT,
                    "VICE Mac: attached disk unit %u:%u path `%s' run mode %d current `%s'.",
                    unit,
                    drive,
                    path,
                    run_mode,
                    current_image != 0 ? current_image : "");
    }

    return result;
}

static void vicemac_dispatch_drive_command(vicemac_drive_command_t *command)
{
    if (!vicemac_drive_unit_is_valid(command->unit)) {
        return;
    }

    switch (command->type) {
        case VICEMAC_DRIVE_COMMAND_RESET:
            drive_cpu_trigger_reset(command->unit - DRIVE_UNIT_MIN);
            break;
        case VICEMAC_DRIVE_COMMAND_ATTACH_DISK:
            (void)vicemac_dispatch_drive_attach_disk(command->unit,
                                                     command->drive,
                                                     command->path,
                                                     command->program_name,
                                                     command->run_mode);
            break;
        case VICEMAC_DRIVE_COMMAND_DETACH_DISK:
            if (command->drive >= NUM_DRIVES) {
                return;
            }
            file_system_detach_disk(command->unit, command->drive);
            break;
        case VICEMAC_DRIVE_COMMAND_PREVIEW_SOUND:
            vicemac_preview_drive_sound((int)(command->unit - DRIVE_UNIT_MIN));
            break;
    }
}

static void vicemac_dispatch_queued_drive_commands(void)
{
    vicemac_drive_command_t command;

    while (vicemac_pop_drive_command(&command)) {
        vicemac_dispatch_drive_command(&command);
    }
}

static void vicemac_dispatch_drive_attach_request(vicemac_drive_attach_request_t *request)
{
    int result;

    if (request == 0) {
        return;
    }

    result = vicemac_dispatch_drive_attach_disk(request->unit,
                                               request->drive,
                                               request->path,
                                               request->program_name,
                                               request->run_mode);
    vicemac_complete_drive_attach_request(request, result == 0);
}

static void vicemac_dispatch_queued_drive_attach_requests(void)
{
    vicemac_drive_attach_request_t *request;

    while (vicemac_pop_drive_attach_request(&request)) {
        vicemac_dispatch_drive_attach_request(request);
    }
}

static void vicemac_dispatch_media_command(vicemac_media_command_t *command)
{
    switch (command->type) {
        case VICEMAC_MEDIA_COMMAND_AUTOSTART:
            if (machine_class == VICE_MACHINE_VSID) {
                if (machine_autodetect_psid(command->path) == 0) {
                    machine_trigger_reset(MACHINE_RESET_MODE_RESET_CPU);
                }
            } else {
                (void)autostart_autodetect(command->path,
                                           0,
                                           0,
                                           command->run_mode == AUTOSTART_MODE_RUN
                                           ? AUTOSTART_MODE_RUN
                                           : AUTOSTART_MODE_LOAD);
            }
            break;
    }
}

static void vicemac_dispatch_queued_media_commands(void)
{
    vicemac_media_command_t command;

    while (vicemac_pop_media_command(&command)) {
        vicemac_dispatch_media_command(&command);
    }
}

static int vicemac_tape_unit_is_valid(uint32_t unit)
{
    return unit == 1 || unit == 2;
}

static void vicemac_dispatch_tape_command(vicemac_tape_command_t *command)
{
    if (!vicemac_tape_unit_is_valid(command->unit)) {
        return;
    }

    switch (command->type) {
        case VICEMAC_TAPE_COMMAND_ATTACH:
            (void)tape_image_attach(command->unit, command->path);
            break;
        case VICEMAC_TAPE_COMMAND_DETACH:
            tape_image_detach(command->unit);
            break;
        case VICEMAC_TAPE_COMMAND_CONTROL:
            datasette_control((int)command->unit - 1, command->control);
            break;
    }
}

static void vicemac_dispatch_queued_tape_commands(void)
{
    vicemac_tape_command_t command;

    while (vicemac_pop_tape_command(&command)) {
        vicemac_dispatch_tape_command(&command);
    }
}

static void vicemac_dispatch_cartridge_command(vicemac_cartridge_command_t *command)
{
    switch (command->type) {
        case VICEMAC_CARTRIDGE_COMMAND_ATTACH:
            (void)cartridge_attach_image(CARTRIDGE_CRT, command->path);
            break;
        case VICEMAC_CARTRIDGE_COMMAND_DETACH:
            cartridge_detach_image(-1);
            break;
    }

    vicemac_publish_current_cartridge_status();
}

static void vicemac_dispatch_queued_cartridge_commands(void)
{
    vicemac_cartridge_command_t command;

    while (vicemac_pop_cartridge_command(&command)) {
        vicemac_dispatch_cartridge_command(&command);
    }
}

void vicemac_dispatch_queued_events(void)
{
    vicemac_dispatch_queued_memory_requests();
    vicemac_dispatch_queued_debugger_requests();
    vicemac_dispatch_queued_resources();
    vicemac_dispatch_queued_resource_requests();
    vicemac_dispatch_queued_machine_commands();
    vicemac_dispatch_queued_snapshot_requests();
    vicemac_dispatch_queued_cartridge_commands();
    vicemac_dispatch_queued_drive_commands();
    vicemac_dispatch_queued_drive_attach_requests();
    vicemac_dispatch_queued_media_commands();
    vicemac_dispatch_queued_tape_commands();
    vicemac_dispatch_queued_joystick_events();
    vicemac_dispatch_queued_mouse_events();
    vicemac_dispatch_queued_input();
}
