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

typedef void (*vicemac_video_frame_callback_t)(const vicemac_video_frame_t *frame,
                                               void *context);

#define VICEMAC_PIXEL_FORMAT_RGBA8 1U

void vicemac_set_video_frame_callback(vicemac_video_frame_callback_t callback,
                                      void *context);
int vicemac_has_video_frame_callback(void);
void vicemac_publish_video_frame(uint32_t width,
                                 uint32_t height,
                                 uint32_t stride,
                                 const uint8_t *pixels);
int vicemac_queue_key_event(signed long key, int mod, int pressed);
int vicemac_queue_keyboard_clear(void);
void vicemac_dispatch_queued_input(void);

#ifdef __cplusplus
}
#endif

#endif
