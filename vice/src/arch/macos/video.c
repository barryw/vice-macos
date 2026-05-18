/*
 * video.c - Native macOS video bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cmdline.h"
#include "machine.h"
#include "palette.h"
#include "resources.h"
#include "vicemacbridge.h"
#include "video.h"
#include "videoarch.h"
#include "viewport.h"

static uint8_t *frame_buffer = NULL;
static size_t frame_buffer_size = 0;

static const cmdline_option_t cmdline_options[] =
{
    CMDLINE_LIST_END
};

static const resource_int_t resources_int[] =
{
    RESOURCE_INT_LIST_END
};

static unsigned int min_uint(unsigned int a, unsigned int b)
{
    return a < b ? a : b;
}

static int ensure_frame_buffer(size_t size)
{
    uint8_t *new_buffer;

    if (frame_buffer_size >= size) {
        return 0;
    }

    new_buffer = (uint8_t *)realloc(frame_buffer, size);
    if (new_buffer == NULL) {
        return -1;
    }

    frame_buffer = new_buffer;
    frame_buffer_size = size;
    return 0;
}

int video_arch_get_active_chip(void)
{
    return VIDEO_CHIP_VICII;
}

void video_arch_canvas_init(struct video_canvas_s *canvas)
{
    if (canvas != NULL && canvas->videoconfig != NULL) {
        canvas->videoconfig->readable = 1;
    }
}

int video_arch_cmdline_options_init(void)
{
    if (machine_class != VICE_MACHINE_VSID) {
        return cmdline_register_options(cmdline_options);
    }
    return 0;
}

int video_arch_resources_init(void)
{
    if (machine_class != VICE_MACHINE_VSID) {
        return resources_register_int(resources_int);
    }
    return 0;
}

void video_arch_resources_shutdown(void)
{
}

char video_canvas_can_resize(video_canvas_t *canvas)
{
    (void)canvas;
    return 1;
}

video_canvas_t *video_canvas_create(video_canvas_t *canvas,
                                    unsigned int *width,
                                    unsigned int *height,
                                    int mapped)
{
    if (canvas == NULL) {
        return NULL;
    }

    if (width != NULL && height != NULL && *width > 0 && *height > 0) {
        canvas->draw_buffer->canvas_width = *width;
        canvas->draw_buffer->canvas_height = *height;
        canvas->draw_buffer->canvas_physical_width =
            *width * canvas->videoconfig->scalex;
        canvas->draw_buffer->canvas_physical_height =
            *height * canvas->videoconfig->scaley;
    }

    canvas->created = 1;
    return canvas;
}

void video_canvas_destroy(struct video_canvas_s *canvas)
{
}

void video_canvas_refresh(struct video_canvas_s *canvas,
                          unsigned int xs,
                          unsigned int ys,
                          unsigned int xi,
                          unsigned int yi,
                          unsigned int w,
                          unsigned int h)
{
    viewport_t *viewport;
    geometry_t *geometry;
    unsigned int width;
    unsigned int height;
    unsigned int render_width;
    unsigned int render_height;
    unsigned int render_xs;
    unsigned int render_ys;
    size_t stride;
    size_t payload_size;

    if (!vicemac_has_video_frame_callback() ||
        canvas == NULL ||
        canvas->draw_buffer == NULL ||
        canvas->videoconfig == NULL ||
        canvas->viewport == NULL ||
        canvas->geometry == NULL) {
        return;
    }

    width = canvas->draw_buffer->canvas_physical_width;
    height = canvas->draw_buffer->canvas_physical_height;
    if (width == 0 || height == 0) {
        return;
    }

    stride = (size_t)width * 4U;
    payload_size = stride * (size_t)height;
    if (payload_size > UINT32_MAX || ensure_frame_buffer(payload_size) < 0) {
        return;
    }

    viewport = canvas->viewport;
    geometry = canvas->geometry;
    if (geometry->screen_size.width <= viewport->first_x ||
        viewport->last_line < viewport->first_line) {
        return;
    }

    render_xs = viewport->first_x + geometry->extra_offscreen_border_left;
    render_ys = viewport->first_line;
    render_width = min_uint(canvas->draw_buffer->canvas_width,
                            geometry->screen_size.width - viewport->first_x);
    render_height = min_uint(canvas->draw_buffer->canvas_height,
                             viewport->last_line - viewport->first_line + 1U);

    if (render_width == 0 || render_height == 0) {
        return;
    }

    memset(frame_buffer, 0, payload_size);
    video_canvas_render(canvas,
                        frame_buffer,
                        (int)render_width,
                        (int)render_height,
                        (int)render_xs,
                        (int)render_ys,
                        (int)viewport->x_offset,
                        (int)viewport->y_offset,
                        (int)stride);

    vicemac_publish_video_frame(width, height, (uint32_t)stride, frame_buffer);
}

void video_canvas_resize(struct video_canvas_s *canvas, char resize_canvas)
{
    (void)resize_canvas;

    if (canvas == NULL || canvas->draw_buffer == NULL || canvas->videoconfig == NULL) {
        return;
    }

    if (canvas->draw_buffer->canvas_physical_width == 0 &&
        canvas->draw_buffer->canvas_width > 0) {
        canvas->draw_buffer->canvas_physical_width =
            canvas->draw_buffer->canvas_width * canvas->videoconfig->scalex;
    }
    if (canvas->draw_buffer->canvas_physical_height == 0 &&
        canvas->draw_buffer->canvas_height > 0) {
        canvas->draw_buffer->canvas_physical_height =
            canvas->draw_buffer->canvas_height * canvas->videoconfig->scaley;
    }
}

int video_canvas_set_palette(struct video_canvas_s *canvas,
                             struct palette_s *palette)
{
    int i;
    video_render_color_tables_t *color_tables;

    if (canvas == NULL || palette == NULL || canvas->videoconfig == NULL) {
        return 0;
    }

    canvas->palette = palette;
    color_tables = &canvas->videoconfig->color_tables;

    for (i = 0; i < (int)palette->num_entries; i++) {
        palette_entry_t color = palette->entries[i];
        uint32_t color_code = color.red | (color.green << 8) | (color.blue << 16) | (0xffU << 24);
        video_render_setphysicalcolor(canvas->videoconfig, i, color_code, 32);
    }

#ifdef WORDS_BIGENDIAN
    for (i = 0; i < 256; i++) {
        video_render_setrawrgb(color_tables, i, i << 24, i << 16, i << 8);
    }
    video_render_setrawalpha(color_tables, 0xffU);
#else
    for (i = 0; i < 256; i++) {
        video_render_setrawrgb(color_tables, i, i, i << 8, i << 16);
    }
    video_render_setrawalpha(color_tables, 0xffU << 24);
#endif
    video_render_initraw(canvas->videoconfig);

    return 0;
}

int video_init(void)
{
    return 0;
}

void video_shutdown(void)
{
    free(frame_buffer);
    frame_buffer = NULL;
    frame_buffer_size = 0;
}
