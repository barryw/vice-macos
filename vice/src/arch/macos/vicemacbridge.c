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

#include "attach.h"
#include "autostart.h"
#include "cartridge.h"
#include "crt.h"
#include "drive.h"
#include "drive-sound.h"
#include "joystick.h"
#include "kbdbuf.h"
#include "keyboard.h"
#include "machine.h"
#include "monitor.h"
#include "monitor/montypes.h"
#include "resources.h"
#include "ui.h"
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
#define VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY 64
#define VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY 64
#define VICEMAC_MEDIA_COMMAND_QUEUE_CAPACITY 32
#define VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY 16
#define VICEMAC_MEMORY_REQUEST_QUEUE_CAPACITY 64
#define VICEMAC_SNAPSHOT_REQUEST_QUEUE_CAPACITY 8
#define VICEMAC_PATH_CAPACITY 4096
#define VICEMAC_CURRENT_MEMORY_BANK -1

typedef enum vicemac_machine_command_type_e {
    VICEMAC_MACHINE_COMMAND_PAUSE,
    VICEMAC_MACHINE_COMMAND_RESET,
    VICEMAC_MACHINE_COMMAND_WARP
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

typedef struct vicemac_machine_command_s {
    vicemac_machine_command_type_t type;
    int value;
} vicemac_machine_command_t;

typedef struct vicemac_drive_command_s {
    vicemac_drive_command_type_t type;
    uint32_t unit;
    uint32_t drive;
    int autorun;
    char path[VICEMAC_PATH_CAPACITY];
} vicemac_drive_command_t;

typedef struct vicemac_media_command_s {
    vicemac_media_command_type_t type;
    int autorun;
    char path[VICEMAC_PATH_CAPACITY];
} vicemac_media_command_t;

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

static vicemac_video_frame_callback_t video_frame_callback = 0;
static void *video_frame_context = 0;
static vicemac_drive_status_callback_t drive_status_callback = 0;
static void *drive_status_context = 0;
static vicemac_cartridge_status_callback_t cartridge_status_callback = 0;
static void *cartridge_status_context = 0;
static uint64_t video_frame_sequence = 0;
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
static pthread_mutex_t joystick_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_joystick_event_t joystick_queue[VICEMAC_JOYSTICK_QUEUE_CAPACITY];
static unsigned int joystick_queue_read = 0;
static unsigned int joystick_queue_write = 0;
static pthread_mutex_t machine_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_machine_command_t machine_command_queue[VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY];
static unsigned int machine_command_queue_read = 0;
static unsigned int machine_command_queue_write = 0;
static pthread_mutex_t drive_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_drive_command_t drive_command_queue[VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY];
static unsigned int drive_command_queue_read = 0;
static unsigned int drive_command_queue_write = 0;
static pthread_mutex_t media_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_media_command_t media_command_queue[VICEMAC_MEDIA_COMMAND_QUEUE_CAPACITY];
static unsigned int media_command_queue_read = 0;
static unsigned int media_command_queue_write = 0;
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

int vicemac_has_video_frame_callback(void)
{
    return video_frame_callback != 0;
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

int vicemac_queue_drive_attach_disk(uint32_t unit,
                                    uint32_t drive,
                                    const char *path,
                                    int autorun)
{
    vicemac_drive_command_t command;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_DRIVE_COMMAND_ATTACH_DISK;
    command.unit = unit;
    command.drive = drive;
    command.autorun = autorun ? 1 : 0;
    vicemac_copy_cstring(command.path, sizeof(command.path), path);

    return vicemac_queue_push(&drive_command_queue_mutex,
                              drive_command_queue,
                              sizeof(drive_command_queue[0]),
                              VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY,
                              &drive_command_queue_read,
                              &drive_command_queue_write,
                              &command);
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

int vicemac_queue_media_autostart(const char *path, int autorun)
{
    vicemac_media_command_t command;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = VICEMAC_MEDIA_COMMAND_AUTOSTART;
    command.autorun = autorun ? 1 : 0;
    vicemac_copy_cstring(command.path, sizeof(command.path), path);

    return vicemac_queue_push(&media_command_queue_mutex,
                              media_command_queue,
                              sizeof(media_command_queue[0]),
                              VICEMAC_MEDIA_COMMAND_QUEUE_CAPACITY,
                              &media_command_queue_read,
                              &media_command_queue_write,
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

static int vicemac_dispatch_machine_model(const char *model)
{
    typedef int (*pet_set_model_function_t)(const char *model_name, void *extra);
    static pet_set_model_function_t pet_set_model_function = 0;
    static int did_lookup_pet_set_model = 0;

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
        case VICEMAC_MACHINE_COMMAND_RESET:
            vsync_suspend_speed_eval();
            machine_trigger_reset((unsigned int)command->value);
            ui_pause_disable();
            break;
        case VICEMAC_MACHINE_COMMAND_WARP:
            vsync_set_warp_mode(command->value);
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
            if (command->drive >= NUM_DRIVES) {
                return;
            }
            if (command->autorun) {
                (void)autostart_disk((int)command->unit,
                                     (int)command->drive,
                                     command->path,
                                     0,
                                     0,
                                     AUTOSTART_MODE_RUN);
            } else {
                (void)file_system_attach_disk(command->unit,
                                              command->drive,
                                              command->path);
            }
            break;
        case VICEMAC_DRIVE_COMMAND_DETACH_DISK:
            if (command->drive >= NUM_DRIVES) {
                return;
            }
            file_system_detach_disk(command->unit, command->drive);
            break;
        case VICEMAC_DRIVE_COMMAND_PREVIEW_SOUND:
            drive_sound_head(18, 1, (int)(command->unit - DRIVE_UNIT_MIN));
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

static void vicemac_dispatch_media_command(vicemac_media_command_t *command)
{
    switch (command->type) {
        case VICEMAC_MEDIA_COMMAND_AUTOSTART:
            (void)autostart_autodetect(command->path,
                                       0,
                                       0,
                                       command->autorun ? AUTOSTART_MODE_RUN : AUTOSTART_MODE_LOAD);
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
    vicemac_dispatch_queued_resources();
    vicemac_dispatch_queued_machine_commands();
    vicemac_dispatch_queued_snapshot_requests();
    vicemac_dispatch_queued_cartridge_commands();
    vicemac_dispatch_queued_drive_commands();
    vicemac_dispatch_queued_media_commands();
    vicemac_dispatch_queued_joystick_events();
    vicemac_dispatch_queued_input();
}
