/*
 * vicemacbridge.c - Native macOS bridge for embedding VICE.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <pthread.h>

#include "keyboard.h"
#include "vicemacbridge.h"

#define VICEMAC_INPUT_QUEUE_CAPACITY 1024

typedef struct vicemac_input_event_s {
    int clear;
    signed long key;
    int mod;
    int pressed;
} vicemac_input_event_t;

static vicemac_video_frame_callback_t video_frame_callback = 0;
static void *video_frame_context = 0;
static uint64_t video_frame_sequence = 0;
static pthread_mutex_t input_queue_mutex = PTHREAD_MUTEX_INITIALIZER;
static vicemac_input_event_t input_queue[VICEMAC_INPUT_QUEUE_CAPACITY];
static unsigned int input_queue_read = 0;
static unsigned int input_queue_write = 0;

static unsigned int input_queue_next(unsigned int index)
{
    return (index + 1) % VICEMAC_INPUT_QUEUE_CAPACITY;
}

void vicemac_set_video_frame_callback(vicemac_video_frame_callback_t callback,
                                      void *context)
{
    video_frame_callback = callback;
    video_frame_context = context;
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

void vicemac_dispatch_queued_input(void)
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
