/*
 * vicemacbridge.h - Native macOS bridge for embedding VICE.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#ifndef VICE_VICEMACBRIDGE_H
#define VICE_VICEMACBRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct vicemac_video_frame_s {
    uint32_t width;
    uint32_t height;
    uint32_t stride;
    uint32_t pixel_format;
    uint64_t sequence;
    const uint8_t *pixels;
} vicemac_video_frame_t;

typedef struct vicemac_drive_status_s {
    uint32_t unit;
    uint32_t enabled;
    int32_t drive_type;
    uint32_t active_drive_number;
    uint32_t led_color;
    uint32_t led_pwm1;
    uint32_t led_pwm2;
    uint32_t drive0_led_intensity;
    uint32_t drive1_led_intensity;
    uint32_t track_valid;
    uint32_t track;
    uint32_t half_track;
    uint32_t disk_side;
    int32_t drive_status_code;
    const char *drive_status_text;
    const char *image_path;
    const char *drive0_image_path;
    const char *drive1_image_path;
} vicemac_drive_status_t;

typedef struct vicemac_cartridge_status_s {
    uint32_t attached;
    int32_t cartridge_id;
    uint32_t cartridge_flags;
    uint32_t rom_size;
    uint32_t chip_count;
    uint32_t bank_count;
    const char *cartridge_name;
    const char *image_path;
} vicemac_cartridge_status_t;

typedef void (*vicemac_video_frame_callback_t)(const vicemac_video_frame_t *frame,
                                               void *context);
typedef void (*vicemac_drive_status_callback_t)(const vicemac_drive_status_t *status,
                                                void *context);
typedef void (*vicemac_cartridge_status_callback_t)(const vicemac_cartridge_status_t *status,
                                                    void *context);

#define VICEMAC_PIXEL_FORMAT_RGBA8 1U

void vicemac_set_video_frame_callback(vicemac_video_frame_callback_t callback,
                                      void *context);
void vicemac_set_drive_status_callback(vicemac_drive_status_callback_t callback,
                                       void *context);
void vicemac_set_cartridge_status_callback(vicemac_cartridge_status_callback_t callback,
                                           void *context);
int vicemac_has_video_frame_callback(void);
void vicemac_publish_video_frame(uint32_t width,
                                 uint32_t height,
                                 uint32_t stride,
                                 const uint8_t *pixels);
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
                                  const char *drive1_image_path);
int vicemac_queue_key_event(signed long key, int mod, int pressed);
int vicemac_queue_keyboard_clear(void);
int vicemac_queue_resource_int(const char *name, int value);
int vicemac_queue_resource_string(const char *name, const char *value);
int vicemac_queue_joystick_value(uint32_t port, uint32_t value);
int vicemac_queue_pause(int paused);
int vicemac_queue_machine_reset(uint32_t reset_mode);
int vicemac_queue_warp_mode(int enabled);
int vicemac_queue_drive_reset(uint32_t unit);
int vicemac_queue_drive_attach_disk(uint32_t unit,
                                    uint32_t drive,
                                    const char *path,
                                    int autorun);
int vicemac_queue_cartridge_attach(const char *path);
int vicemac_queue_cartridge_detach(void);
void vicemac_dispatch_queued_events(void);

#ifdef __cplusplus
}
#endif

#endif
