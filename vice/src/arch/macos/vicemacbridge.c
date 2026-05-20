/*
 * vicemacbridge.c - Native macOS bridge for embedding VICE.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <pthread.h>
#include <stdio.h>
#include <string.h>

#include "attach.h"
#include "autostart.h"
#include "cartridge.h"
#include "crt.h"
#include "drive.h"
#include "joystick.h"
#include "keyboard.h"
#include "machine.h"
#include "resources.h"
#include "ui.h"
#include "vicemacbridge.h"
#include "vsync.h"

#define VICEMAC_INPUT_QUEUE_CAPACITY 1024
#define VICEMAC_RESOURCE_QUEUE_CAPACITY 256
#define VICEMAC_RESOURCE_NAME_CAPACITY 64
#define VICEMAC_JOYSTICK_QUEUE_CAPACITY 256
#define VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY 64
#define VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY 64
#define VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY 16
#define VICEMAC_PATH_CAPACITY 4096

typedef enum vicemac_machine_command_type_e {
    VICEMAC_MACHINE_COMMAND_PAUSE,
    VICEMAC_MACHINE_COMMAND_RESET,
    VICEMAC_MACHINE_COMMAND_WARP
} vicemac_machine_command_type_t;

typedef enum vicemac_drive_command_type_e {
    VICEMAC_DRIVE_COMMAND_RESET,
    VICEMAC_DRIVE_COMMAND_ATTACH_DISK
} vicemac_drive_command_type_t;

typedef enum vicemac_cartridge_command_type_e {
    VICEMAC_CARTRIDGE_COMMAND_ATTACH,
    VICEMAC_CARTRIDGE_COMMAND_DETACH
} vicemac_cartridge_command_type_t;

typedef struct vicemac_input_event_s {
    int clear;
    signed long key;
    int mod;
    int pressed;
} vicemac_input_event_t;

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

typedef struct vicemac_cartridge_command_s {
    vicemac_cartridge_command_type_t type;
    char path[VICEMAC_PATH_CAPACITY];
} vicemac_cartridge_command_t;

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
static pthread_mutex_t cartridge_command_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_cartridge_command_t cartridge_command_queue[VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY];
static unsigned int cartridge_command_queue_read = 0;
static unsigned int cartridge_command_queue_write = 0;

static unsigned int input_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_INPUT_QUEUE_CAPACITY;
}

static unsigned int resource_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_RESOURCE_QUEUE_CAPACITY;
}

static unsigned int resource_string_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_RESOURCE_QUEUE_CAPACITY;
}

static unsigned int joystick_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_JOYSTICK_QUEUE_CAPACITY;
}

static unsigned int machine_command_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_MACHINE_COMMAND_QUEUE_CAPACITY;
}

static unsigned int drive_command_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_DRIVE_COMMAND_QUEUE_CAPACITY;
}

static unsigned int cartridge_command_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_CARTRIDGE_COMMAND_QUEUE_CAPACITY;
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
    uint32_t seen_banks[2048];
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
    unsigned int next_write;

    if (key == 0) {
        return 0;
    }

    pthread_mutex_lock(&input_queue_mutex);

    next_write = input_queue_next(input_queue_write);
    if (next_write == input_queue_read) {
        input_queue_read = input_queue_next(input_queue_read);
    }

    input_queue[input_queue_write].clear = 0;
    input_queue[input_queue_write].key = key;
    input_queue[input_queue_write].mod = mod;
    input_queue[input_queue_write].pressed = pressed ? 1 : 0;
    input_queue_write = next_write;

    pthread_mutex_unlock(&input_queue_mutex);
    return 1;
}

int vicemac_queue_keyboard_clear(void)
{
    unsigned int next_write;

    pthread_mutex_lock(&input_queue_mutex);

    next_write = input_queue_next(input_queue_write);
    if (next_write == input_queue_read) {
        input_queue_read = input_queue_next(input_queue_read);
    }

    input_queue[input_queue_write].clear = 1;
    input_queue[input_queue_write].key = 0;
    input_queue[input_queue_write].mod = 0;
    input_queue[input_queue_write].pressed = 0;
    input_queue_write = next_write;

    pthread_mutex_unlock(&input_queue_mutex);
    return 1;
}

int vicemac_queue_resource_int(const char *name, int value)
{
    unsigned int next_write;

    if (name == 0 || name[0] == '\0') {
        return 0;
    }

    pthread_mutex_lock(&resource_queue_mutex);

    next_write = resource_queue_next(resource_queue_write);
    if (next_write == resource_queue_read) {
        resource_queue_read = resource_queue_next(resource_queue_read);
    }

    strncpy(resource_queue[resource_queue_write].name,
            name,
            sizeof(resource_queue[resource_queue_write].name) - 1);
    resource_queue[resource_queue_write].name[sizeof(resource_queue[resource_queue_write].name) - 1] = '\0';
    resource_queue[resource_queue_write].value = value;
    resource_queue_write = next_write;

    pthread_mutex_unlock(&resource_queue_mutex);
    return 1;
}

int vicemac_queue_resource_string(const char *name, const char *value)
{
    unsigned int next_write;

    if (name == 0 || name[0] == '\0' || value == 0) {
        return 0;
    }

    pthread_mutex_lock(&resource_string_queue_mutex);

    next_write = resource_string_queue_next(resource_string_queue_write);
    if (next_write == resource_string_queue_read) {
        resource_string_queue_read = resource_string_queue_next(resource_string_queue_read);
    }

    strncpy(resource_string_queue[resource_string_queue_write].name,
            name,
            sizeof(resource_string_queue[resource_string_queue_write].name) - 1);
    resource_string_queue[resource_string_queue_write].name[sizeof(resource_string_queue[resource_string_queue_write].name) - 1] = '\0';
    strncpy(resource_string_queue[resource_string_queue_write].value,
            value,
            sizeof(resource_string_queue[resource_string_queue_write].value) - 1);
    resource_string_queue[resource_string_queue_write].value[sizeof(resource_string_queue[resource_string_queue_write].value) - 1] = '\0';
    resource_string_queue_write = next_write;

    pthread_mutex_unlock(&resource_string_queue_mutex);
    return 1;
}

int vicemac_queue_joystick_value(uint32_t port, uint32_t value)
{
    unsigned int next_write;

    if (port >= JOYPORT_MAX_PORTS) {
        return 0;
    }

    pthread_mutex_lock(&joystick_queue_mutex);

    next_write = joystick_queue_next(joystick_queue_write);
    if (next_write == joystick_queue_read) {
        joystick_queue_read = joystick_queue_next(joystick_queue_read);
    }

    joystick_queue[joystick_queue_write].port = port;
    joystick_queue[joystick_queue_write].value = value;
    joystick_queue_write = next_write;

    pthread_mutex_unlock(&joystick_queue_mutex);
    return 1;
}

static int vicemac_queue_machine_command(vicemac_machine_command_type_t type, int value)
{
    unsigned int next_write;

    pthread_mutex_lock(&machine_command_queue_mutex);

    next_write = machine_command_queue_next(machine_command_queue_write);
    if (next_write == machine_command_queue_read) {
        machine_command_queue_read = machine_command_queue_next(machine_command_queue_read);
    }

    machine_command_queue[machine_command_queue_write].type = type;
    machine_command_queue[machine_command_queue_write].value = value;
    machine_command_queue_write = next_write;

    pthread_mutex_unlock(&machine_command_queue_mutex);
    return 1;
}

int vicemac_queue_pause(int paused)
{
    return vicemac_queue_machine_command(VICEMAC_MACHINE_COMMAND_PAUSE,
                                         paused ? 1 : 0);
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
    unsigned int next_write;

    pthread_mutex_lock(&drive_command_queue_mutex);

    next_write = drive_command_queue_next(drive_command_queue_write);
    if (next_write == drive_command_queue_read) {
        drive_command_queue_read = drive_command_queue_next(drive_command_queue_read);
    }

    drive_command_queue[drive_command_queue_write].type = VICEMAC_DRIVE_COMMAND_RESET;
    drive_command_queue[drive_command_queue_write].unit = unit;
    drive_command_queue[drive_command_queue_write].drive = 0;
    drive_command_queue[drive_command_queue_write].autorun = 0;
    drive_command_queue[drive_command_queue_write].path[0] = '\0';
    drive_command_queue_write = next_write;

    pthread_mutex_unlock(&drive_command_queue_mutex);
    return 1;
}

int vicemac_queue_drive_attach_disk(uint32_t unit,
                                    uint32_t drive,
                                    const char *path,
                                    int autorun)
{
    unsigned int next_write;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    pthread_mutex_lock(&drive_command_queue_mutex);

    next_write = drive_command_queue_next(drive_command_queue_write);
    if (next_write == drive_command_queue_read) {
        drive_command_queue_read = drive_command_queue_next(drive_command_queue_read);
    }

    drive_command_queue[drive_command_queue_write].type = VICEMAC_DRIVE_COMMAND_ATTACH_DISK;
    drive_command_queue[drive_command_queue_write].unit = unit;
    drive_command_queue[drive_command_queue_write].drive = drive;
    drive_command_queue[drive_command_queue_write].autorun = autorun ? 1 : 0;
    strncpy(drive_command_queue[drive_command_queue_write].path,
            path,
            sizeof(drive_command_queue[drive_command_queue_write].path) - 1);
    drive_command_queue[drive_command_queue_write].path[sizeof(drive_command_queue[drive_command_queue_write].path) - 1] = '\0';
    drive_command_queue_write = next_write;

    pthread_mutex_unlock(&drive_command_queue_mutex);
    return 1;
}

int vicemac_queue_cartridge_attach(const char *path)
{
    unsigned int next_write;

    if (path == 0 || path[0] == '\0') {
        return 0;
    }

    pthread_mutex_lock(&cartridge_command_queue_mutex);

    next_write = cartridge_command_queue_next(cartridge_command_queue_write);
    if (next_write == cartridge_command_queue_read) {
        cartridge_command_queue_read = cartridge_command_queue_next(cartridge_command_queue_read);
    }

    cartridge_command_queue[cartridge_command_queue_write].type = VICEMAC_CARTRIDGE_COMMAND_ATTACH;
    strncpy(cartridge_command_queue[cartridge_command_queue_write].path,
            path,
            sizeof(cartridge_command_queue[cartridge_command_queue_write].path) - 1);
    cartridge_command_queue[cartridge_command_queue_write].path[sizeof(cartridge_command_queue[cartridge_command_queue_write].path) - 1] = '\0';
    cartridge_command_queue_write = next_write;

    pthread_mutex_unlock(&cartridge_command_queue_mutex);
    return 1;
}

int vicemac_queue_cartridge_detach(void)
{
    unsigned int next_write;

    pthread_mutex_lock(&cartridge_command_queue_mutex);

    next_write = cartridge_command_queue_next(cartridge_command_queue_write);
    if (next_write == cartridge_command_queue_read) {
        cartridge_command_queue_read = cartridge_command_queue_next(cartridge_command_queue_read);
    }

    cartridge_command_queue[cartridge_command_queue_write].type = VICEMAC_CARTRIDGE_COMMAND_DETACH;
    cartridge_command_queue[cartridge_command_queue_write].path[0] = '\0';
    cartridge_command_queue_write = next_write;

    pthread_mutex_unlock(&cartridge_command_queue_mutex);
    return 1;
}

static int vicemac_pop_key_event(vicemac_input_event_t *event)
{
    int has_event = 0;

    pthread_mutex_lock(&input_queue_mutex);

    if (input_queue_read != input_queue_write) {
        *event = input_queue[input_queue_read];
        input_queue_read = input_queue_next(input_queue_read);
        has_event = 1;
    }

    pthread_mutex_unlock(&input_queue_mutex);
    return has_event;
}

static int vicemac_pop_resource_int_event(vicemac_resource_int_event_t *event)
{
    int has_event = 0;

    pthread_mutex_lock(&resource_queue_mutex);

    if (resource_queue_read != resource_queue_write) {
        *event = resource_queue[resource_queue_read];
        resource_queue_read = resource_queue_next(resource_queue_read);
        has_event = 1;
    }

    pthread_mutex_unlock(&resource_queue_mutex);
    return has_event;
}

static int vicemac_pop_resource_string_event(vicemac_resource_string_event_t *event)
{
    int has_event = 0;

    pthread_mutex_lock(&resource_string_queue_mutex);

    if (resource_string_queue_read != resource_string_queue_write) {
        *event = resource_string_queue[resource_string_queue_read];
        resource_string_queue_read = resource_string_queue_next(resource_string_queue_read);
        has_event = 1;
    }

    pthread_mutex_unlock(&resource_string_queue_mutex);
    return has_event;
}

static int vicemac_pop_joystick_event(vicemac_joystick_event_t *event)
{
    int has_event = 0;

    pthread_mutex_lock(&joystick_queue_mutex);

    if (joystick_queue_read != joystick_queue_write) {
        *event = joystick_queue[joystick_queue_read];
        joystick_queue_read = joystick_queue_next(joystick_queue_read);
        has_event = 1;
    }

    pthread_mutex_unlock(&joystick_queue_mutex);
    return has_event;
}

static int vicemac_pop_machine_command(vicemac_machine_command_t *command)
{
    int has_command = 0;

    pthread_mutex_lock(&machine_command_queue_mutex);

    if (machine_command_queue_read != machine_command_queue_write) {
        *command = machine_command_queue[machine_command_queue_read];
        machine_command_queue_read = machine_command_queue_next(machine_command_queue_read);
        has_command = 1;
    }

    pthread_mutex_unlock(&machine_command_queue_mutex);
    return has_command;
}

static int vicemac_pop_drive_command(vicemac_drive_command_t *command)
{
    int has_command = 0;

    pthread_mutex_lock(&drive_command_queue_mutex);

    if (drive_command_queue_read != drive_command_queue_write) {
        *command = drive_command_queue[drive_command_queue_read];
        drive_command_queue_read = drive_command_queue_next(drive_command_queue_read);
        has_command = 1;
    }

    pthread_mutex_unlock(&drive_command_queue_mutex);
    return has_command;
}

static int vicemac_pop_cartridge_command(vicemac_cartridge_command_t *command)
{
    int has_command = 0;

    pthread_mutex_lock(&cartridge_command_queue_mutex);

    if (cartridge_command_queue_read != cartridge_command_queue_write) {
        *command = cartridge_command_queue[cartridge_command_queue_read];
        cartridge_command_queue_read = cartridge_command_queue_next(cartridge_command_queue_read);
        has_command = 1;
    }

    pthread_mutex_unlock(&cartridge_command_queue_mutex);
    return has_command;
}

static void vicemac_dispatch_queued_resources(void)
{
    vicemac_resource_int_event_t int_event;
    vicemac_resource_string_event_t string_event;

    while (vicemac_pop_resource_int_event(&int_event)) {
        (void)resources_set_int(int_event.name, int_event.value);
    }

    while (vicemac_pop_resource_string_event(&string_event)) {
        (void)resources_set_string(string_event.name, string_event.value);
    }
}

static void vicemac_dispatch_queued_input(void)
{
    vicemac_input_event_t event;

    while (vicemac_pop_key_event(&event)) {
        if (event.clear) {
            keyboard_key_clear();
        } else if (event.pressed) {
            keyboard_key_pressed(event.key, event.mod);
        } else {
            keyboard_key_released(event.key, event.mod);
        }
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
    }
}

static void vicemac_dispatch_queued_drive_commands(void)
{
    vicemac_drive_command_t command;

    while (vicemac_pop_drive_command(&command)) {
        vicemac_dispatch_drive_command(&command);
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
    vicemac_dispatch_queued_resources();
    vicemac_dispatch_queued_machine_commands();
    vicemac_dispatch_queued_cartridge_commands();
    vicemac_dispatch_queued_drive_commands();
    vicemac_dispatch_queued_joystick_events();
    vicemac_dispatch_queued_input();
}
