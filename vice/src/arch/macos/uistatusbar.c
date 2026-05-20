/*
 * uistatusbar.c - Native macOS status callbacks.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdbool.h>
#include <string.h>

#include "attach.h"
#include "cbmdos.h"
#include "drive.h"
#include "lib.h"
#include "resources.h"
#include "uiapi.h"
#include "uistatusbar.h"
#include "vdrive/vdrive.h"
#include "vicemacbridge.h"

static int drive_status_enabled[NUM_DISK_UNITS] = { 0, 0, 0, 0 };
static int drive_status_type[NUM_DISK_UNITS] = { 0, 0, 0, 0 };
static int drive_status_led_color[NUM_DISK_UNITS] = {
    DRIVE_LED1_RED,
    DRIVE_LED1_RED,
    DRIVE_LED1_RED,
    DRIVE_LED1_RED
};
static unsigned int drive_status_led_pwm1[NUM_DISK_UNITS][NUM_DRIVES] = { { 0 } };
static unsigned int drive_status_led_pwm2[NUM_DISK_UNITS][NUM_DRIVES] = { { 0 } };
static unsigned int drive_status_track_valid[NUM_DISK_UNITS][NUM_DRIVES] = { { 0 } };
static unsigned int drive_status_half_track[NUM_DISK_UNITS][NUM_DRIVES] = { { 0 } };
static unsigned int drive_status_disk_side[NUM_DISK_UNITS][NUM_DRIVES] = { { 0 } };
static unsigned int drive_status_current_base[NUM_DISK_UNITS] = { 0, 0, 0, 0 };
static char *drive_status_image[NUM_DISK_UNITS][NUM_DRIVES] = { { 0 } };
static char drive_status_text[NUM_DISK_UNITS][96] = { { 0 } };

static const char *drive_image(unsigned int drive_number, unsigned int drive_base)
{
    if (drive_number >= NUM_DISK_UNITS || drive_base >= NUM_DRIVES) {
        return "";
    }

    if (drive_status_image[drive_number][drive_base] != 0
        && drive_status_image[drive_number][drive_base][0] != '\0') {
        return drive_status_image[drive_number][drive_base];
    }

    return "";
}

static unsigned int drive_led_intensity(unsigned int drive_number, unsigned int drive_base)
{
    unsigned int led1;
    unsigned int led2;

    if (drive_number >= NUM_DISK_UNITS || drive_base >= NUM_DRIVES) {
        return 0;
    }

    led1 = drive_status_led_pwm1[drive_number][drive_base];
    led2 = drive_status_led_pwm2[drive_number][drive_base];
    return led1 > led2 ? led1 : led2;
}

static const char *current_drive_image(unsigned int drive_number)
{
    unsigned int drive_base;

    for (drive_base = 0; drive_base < NUM_DRIVES; drive_base++) {
        const char *image = drive_image(drive_number, drive_base);
        if (image[0] != '\0') {
            return image;
        }
    }

    return "";
}

static int current_drive_status_code(unsigned int drive_number)
{
    vdrive_t *vdrive = file_system_get_vdrive(drive_number + DRIVE_UNIT_MIN);

    if (vdrive == 0) {
        return CBMDOS_IPE_OK;
    }

    return vdrive->last_code;
}

static const char *current_drive_status_text(unsigned int drive_number)
{
    vdrive_t *vdrive = file_system_get_vdrive(drive_number + DRIVE_UNIT_MIN);
    const uint8_t *source;
    size_t length;

    if (vdrive == 0) {
        return "";
    }

    source = vdrive->buffers[15].buffer;
    if (source == 0) {
        return "";
    }

    for (length = 0;
         length < sizeof(drive_status_text[drive_number]) - 1
             && source[length] != '\0'
             && source[length] != '\r'
             && source[length] != '\n';
         length++) {
        drive_status_text[drive_number][length] = (char)source[length];
    }

    drive_status_text[drive_number][length] = '\0';
    return drive_status_text[drive_number];
}

static void publish_drive_status(unsigned int drive_number)
{
    unsigned int drive_base = 0;
    unsigned int track_valid = 0;
    unsigned int half_track = 0;
    unsigned int disk_side = 0;

    if (drive_number >= NUM_DISK_UNITS) {
        return;
    }

    if (drive_status_current_base[drive_number] < NUM_DRIVES) {
        drive_base = drive_status_current_base[drive_number];
    }

    if (!drive_status_track_valid[drive_number][drive_base]) {
        for (drive_base = 0; drive_base < NUM_DRIVES; drive_base++) {
            if (drive_status_track_valid[drive_number][drive_base]) {
                break;
            }
        }
    }

    if (drive_base < NUM_DRIVES && drive_status_track_valid[drive_number][drive_base]) {
        track_valid = 1;
        half_track = drive_status_half_track[drive_number][drive_base];
        disk_side = drive_status_disk_side[drive_number][drive_base];
    }

    vicemac_publish_drive_status(drive_number + DRIVE_UNIT_MIN,
                                 (uint32_t)drive_status_enabled[drive_number],
                                 drive_status_type[drive_number],
                                 (uint32_t)drive_base,
                                 (uint32_t)drive_status_led_color[drive_number],
                                 drive_status_led_pwm1[drive_number][drive_base],
                                 drive_status_led_pwm2[drive_number][drive_base],
                                 drive_led_intensity(drive_number, 0),
                                 drive_led_intensity(drive_number, 1),
                                 (uint32_t)track_valid,
                                 (uint32_t)(half_track / 2),
                                 (uint32_t)half_track,
                                 (uint32_t)disk_side,
                                 current_drive_status_code(drive_number),
                                 current_drive_status_text(drive_number),
                                 current_drive_image(drive_number),
                                 drive_image(drive_number, 0),
                                 drive_image(drive_number, 1));
}

void ui_display_event_time(unsigned int current, unsigned int total)
{
    (void)current;
    (void)total;
}

void ui_display_playback(int playback_status, char *version)
{
    (void)playback_status;
    (void)version;
}

void ui_display_recording(int recording_status)
{
    (void)recording_status;
}

void ui_display_statustext(const char *text, bool fadeout)
{
    (void)text;
    (void)fadeout;
}

void ui_display_volume(int vol)
{
    (void)vol;
}

void ui_display_joyport(uint16_t *joyport)
{
    (void)joyport;
}

void ui_display_tape_control_status(int port, int control)
{
    (void)port;
    (void)control;
}

void ui_display_tape_counter(int port, int counter)
{
    (void)port;
    (void)counter;
}

void ui_display_tape_motor_status(int port, int motor)
{
    (void)port;
    (void)motor;
}

void ui_set_tape_status(int port, int tape_status)
{
    (void)port;
    (void)tape_status;
}

void ui_display_tape_current_image(int port, const char *image)
{
    (void)port;
    (void)image;
}

void ui_display_drive_led(unsigned int drive_number,
                          unsigned int drive_base,
                          unsigned int led_pwm1,
                          unsigned int led_pwm2)
{
    if (drive_number >= NUM_DISK_UNITS || drive_base >= NUM_DRIVES) {
        return;
    }

    drive_status_led_pwm1[drive_number][drive_base] = led_pwm1;
    drive_status_led_pwm2[drive_number][drive_base] = led_pwm2;
    drive_status_current_base[drive_number] = drive_base;
    publish_drive_status(drive_number);
}

void ui_display_drive_track(unsigned int drive_number,
                            unsigned int drive_base,
                            unsigned int half_track_number,
                            unsigned int disk_side)
{
    int changed;

    if (drive_number >= NUM_DISK_UNITS || drive_base >= NUM_DRIVES) {
        return;
    }

    changed = drive_status_current_base[drive_number] != drive_base
        || !drive_status_track_valid[drive_number][drive_base]
        || drive_status_half_track[drive_number][drive_base] != half_track_number
        || drive_status_disk_side[drive_number][drive_base] != disk_side;

    drive_status_track_valid[drive_number][drive_base] = 1;
    drive_status_half_track[drive_number][drive_base] = half_track_number;
    drive_status_disk_side[drive_number][drive_base] = disk_side;
    drive_status_current_base[drive_number] = drive_base;

    if (changed) {
        publish_drive_status(drive_number);
    }
}

void ui_enable_drive_status(ui_drive_enable_t state, int *drive_led_color)
{
    unsigned int unit;

    for (unit = 0; unit < NUM_DISK_UNITS; unit++) {
        int drive_type = DRIVE_TYPE_NONE;

        (void)resources_get_int_sprintf("Drive%uType", &drive_type, unit + DRIVE_UNIT_MIN);

        drive_status_enabled[unit] = drive_type != DRIVE_TYPE_NONE;
        drive_status_type[unit] = drive_type;
        drive_status_led_color[unit] = drive_led_color != NULL
            ? drive_led_color[unit]
            : DRIVE_LED1_RED;

        if ((state & (1 << unit)) == 0) {
            memset(drive_status_led_pwm1[unit], 0, sizeof(drive_status_led_pwm1[unit]));
            memset(drive_status_led_pwm2[unit], 0, sizeof(drive_status_led_pwm2[unit]));
            memset(drive_status_track_valid[unit], 0, sizeof(drive_status_track_valid[unit]));
        }

        publish_drive_status(unit);
    }
}

void ui_display_drive_current_image(unsigned int unit_number,
                                    unsigned int drive_number,
                                    const char *image)
{
    if (unit_number >= NUM_DISK_UNITS || drive_number >= NUM_DRIVES) {
        return;
    }

    lib_free(drive_status_image[unit_number][drive_number]);
    drive_status_image[unit_number][drive_number] = lib_strdup(image != 0 ? image : "");
    if (image == 0 || image[0] == '\0') {
        drive_status_track_valid[unit_number][drive_number] = 0;
    }
    publish_drive_status(unit_number);
}

void ui_display_reset(int device, int mode)
{
    (void)device;
    (void)mode;
}
