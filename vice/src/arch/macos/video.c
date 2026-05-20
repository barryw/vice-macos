/*
 * video.c - Native macOS video bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdint.h>
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
static video_canvas_t *active_canvas = NULL;
static video_canvas_t *vicii_canvas = NULL;
static video_canvas_t *vdc_canvas = NULL;
static uint64_t published_frame_count = 0;
static uint64_t last_vsync_frame_count = 0;

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

static int max_int(int a, int b)
{
    return a > b ? a : b;
}

static int min_int(int a, int b)
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

static int is_c128_machine(void)
{
    return machine_class == VICE_MACHINE_C128;
}

static int canvas_chip(video_canvas_t *canvas)
{
    if (canvas != NULL &&
        canvas->videoconfig != NULL &&
        canvas->videoconfig->chip_name != NULL &&
        strcmp(canvas->videoconfig->chip_name, "VDC") == 0) {
        return VIDEO_CHIP_VDC;
    }

    return VIDEO_CHIP_VICII;
}

static int c128_column_key(void)
{
    int column_key = 1;

    if (is_c128_machine() &&
        resources_get_int("C128ColumnKey", &column_key) == 0) {
        return column_key ? 1 : 0;
    }

    return 1;
}

static void update_active_canvas(void)
{
    if (is_c128_machine()) {
        if (c128_column_key() == 0 && vdc_canvas != NULL) {
            active_canvas = vdc_canvas;
            return;
        }

        if (vicii_canvas != NULL) {
            active_canvas = vicii_canvas;
            return;
        }
    }

    if (active_canvas == NULL) {
        active_canvas = vicii_canvas != NULL ? vicii_canvas : vdc_canvas;
    }
}

static unsigned int render_scale_for_axis(unsigned int scale,
                                          unsigned int canvas_size,
                                          unsigned int limit)
{
    if (scale > 1 && (limit == 0 || canvas_size <= limit)) {
        return scale;
    }

    return 1;
}

static void sync_render_config_from_cap(video_canvas_t *canvas)
{
    video_render_config_t *config;
    video_chip_cap_t *cap;
    cap_render_t *cap_render;

    if (canvas == NULL || canvas->draw_buffer == NULL || canvas->videoconfig == NULL) {
        return;
    }

    config = canvas->videoconfig;
    cap = config->cap;
    if (cap == NULL) {
        return;
    }

    cap_render = config->double_size_enabled ? &cap->double_mode : &cap->single_mode;
    if (cap_render->rmode == VIDEO_RENDER_NULL) {
        return;
    }

    config->rendermode = cap_render->rmode;
    config->scalex = render_scale_for_axis(cap_render->sizex,
                                           canvas->draw_buffer->canvas_width,
                                           cap->dsize_limit_width);
    config->scaley = render_scale_for_axis(cap_render->sizey,
                                           canvas->draw_buffer->canvas_height,
                                           cap->dsize_limit_height);

    if (canvas->draw_buffer->canvas_width > 0) {
        canvas->draw_buffer->canvas_physical_width =
            canvas->draw_buffer->canvas_width * config->scalex;
    }
    if (canvas->draw_buffer->canvas_height > 0) {
        canvas->draw_buffer->canvas_physical_height =
            canvas->draw_buffer->canvas_height * config->scaley;
    }
}

static void calculate_visible_area(video_canvas_t *canvas,
                                   unsigned int *first_x_out,
                                   unsigned int *first_line_out,
                                   unsigned int *x_offset_out,
                                   unsigned int *y_offset_out,
                                   unsigned int *width_out,
                                   unsigned int *height_out)
{
    geometry_t *geometry = canvas->geometry;
    rectangle_t *screen_size = &geometry->screen_size;
    rectangle_t *gfx_size = &geometry->gfx_size;
    position_t *gfx_position = &geometry->gfx_position;
    int canvas_width = (int)canvas->draw_buffer->canvas_width;
    int canvas_height = (int)canvas->draw_buffer->canvas_height;
    int first_x;
    int first_line;
    int x_offset;
    int y_offset;
    int real_gfx_height;
    int displayed_width;
    int displayed_height;
    int small_x_border;
    int small_y_border;

    if (canvas_width <= 0 || canvas_height <= 0) {
        *first_x_out = 0;
        *first_line_out = 0;
        *x_offset_out = 0;
        *y_offset_out = 0;
        *width_out = 0;
        *height_out = 0;
        return;
    }

    small_x_border = (int)screen_size->width - (int)gfx_position->x - (int)gfx_size->width;
    small_x_border = min_int(small_x_border, (int)gfx_position->x);

    if ((int)gfx_size->width + small_x_border * 2 > canvas_width) {
        first_x = (int)gfx_position->x - (canvas_width - (int)gfx_size->width) / 2;
    } else if ((int)gfx_position->x > small_x_border) {
        first_x = (int)screen_size->width - canvas_width;
    } else {
        first_x = 0;
    }

    x_offset = (canvas_width - (int)screen_size->width) / 2;
    x_offset = max_int(x_offset, 0);
    first_x = max_int(first_x, 0);

    if (!geometry->gfx_area_moves && first_x > (int)gfx_position->x) {
        first_x = (int)gfx_position->x;
    }

    real_gfx_height = (int)geometry->last_displayed_line - (int)geometry->first_displayed_line + 1;
    small_y_border = (int)geometry->last_displayed_line - (int)gfx_position->y - (int)gfx_size->height + 1;
    small_y_border = min_int(small_y_border,
                             (int)gfx_position->y - (int)geometry->first_displayed_line);

    if ((int)gfx_size->height + small_y_border * 2 > canvas_height) {
        first_line = (int)gfx_position->y - (canvas_height - (int)gfx_size->height) / 2;
    } else if ((int)gfx_position->y - (int)geometry->first_displayed_line > small_y_border) {
        first_line = real_gfx_height - canvas_height + (int)geometry->first_displayed_line;
    } else {
        first_line = (int)geometry->first_displayed_line;
    }

    y_offset = (canvas_height - real_gfx_height) / 2;
    y_offset = max_int(y_offset, 0);

    if (geometry->gfx_area_moves) {
        int centered_line = (int)gfx_position->y - (canvas_height - (int)gfx_size->height) / 2;
        first_line = max_int(centered_line, (int)geometry->first_displayed_line);
    } else {
        first_line = max_int(first_line, (int)geometry->first_displayed_line);

        if (first_line > (int)gfx_position->y) {
            first_line = (int)gfx_position->y;
        }
    }

    displayed_width = min_int(canvas_width, (int)screen_size->width - first_x);
    displayed_height = min_int(canvas_height,
                               (int)geometry->last_displayed_line - first_line + 1);

    *first_x_out = (unsigned int)max_int(first_x, 0);
    *first_line_out = (unsigned int)max_int(first_line, 0);
    *x_offset_out = (unsigned int)max_int(x_offset, 0);
    *y_offset_out = (unsigned int)max_int(y_offset, 0);
    *width_out = (unsigned int)max_int(displayed_width, 0);
    *height_out = (unsigned int)max_int(displayed_height, 0);
}

static void extend_last_rendered_line(uint8_t *buffer,
                                      size_t stride,
                                      unsigned int rendered_height,
                                      unsigned int target_height)
{
    unsigned int y;
    uint8_t *source;

    if (rendered_height == 0 || rendered_height >= target_height) {
        return;
    }

    source = buffer + ((size_t)rendered_height - 1U) * stride;
    for (y = rendered_height; y < target_height; y++) {
        memcpy(buffer + (size_t)y * stride, source, stride);
    }
}

int video_arch_get_active_chip(void)
{
    if (is_c128_machine() && c128_column_key() == 0) {
        return VIDEO_CHIP_VDC;
    }

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
        sync_render_config_from_cap(canvas);
        canvas->draw_buffer->canvas_physical_width =
            *width * canvas->videoconfig->scalex;
        canvas->draw_buffer->canvas_physical_height =
            *height * canvas->videoconfig->scaley;
    } else {
        sync_render_config_from_cap(canvas);
    }

    canvas->created = 1;
    if (canvas_chip(canvas) == VIDEO_CHIP_VDC) {
        vdc_canvas = canvas;
    } else {
        vicii_canvas = canvas;
    }
    active_canvas = canvas;
    update_active_canvas();
    return canvas;
}

void video_canvas_destroy(struct video_canvas_s *canvas)
{
    if (vicii_canvas == canvas) {
        vicii_canvas = NULL;
    }
    if (vdc_canvas == canvas) {
        vdc_canvas = NULL;
    }
    if (active_canvas == canvas) {
        active_canvas = NULL;
    }
    update_active_canvas();
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
    unsigned int render_xi;
    unsigned int render_yi;
    unsigned int render_bottom;
    size_t stride;
    size_t payload_size;

    (void)xs;
    (void)ys;
    (void)xi;
    (void)yi;
    (void)w;
    (void)h;

    if (!vicemac_has_video_frame_callback() ||
        canvas == NULL ||
        canvas->draw_buffer == NULL ||
        canvas->videoconfig == NULL ||
        canvas->viewport == NULL ||
        canvas->geometry == NULL) {
        return;
    }

    update_active_canvas();
    if (canvas != active_canvas) {
        return;
    }

    sync_render_config_from_cap(canvas);

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

    calculate_visible_area(canvas,
                           &render_xs,
                           &render_ys,
                           &render_xi,
                           &render_yi,
                           &render_width,
                           &render_height);
    render_xs += geometry->extra_offscreen_border_left;
    render_xi *= canvas->videoconfig->scalex;
    render_yi *= canvas->videoconfig->scaley;
    render_width *= canvas->videoconfig->scalex;
    render_height *= canvas->videoconfig->scaley;
    render_width = min_uint(render_width, width - min_uint(render_xi, width));
    render_height = min_uint(render_height, height - min_uint(render_yi, height));

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
                        (int)render_xi,
                        (int)render_yi,
                        (int)stride);

    render_bottom = render_yi + render_height;
    if (render_xi == 0 && render_bottom < height) {
        extend_last_rendered_line(frame_buffer,
                                  stride,
                                  render_bottom,
                                  height);
    }

    vicemac_publish_video_frame(width, height, (uint32_t)stride, frame_buffer);
    published_frame_count++;
}

video_canvas_t *vicemac_video_active_canvas(void)
{
    update_active_canvas();
    return active_canvas;
}

void vicemac_video_refresh_if_idle(void)
{
    update_active_canvas();

    if (active_canvas == NULL || !vicemac_has_video_frame_callback()) {
        return;
    }

    if (published_frame_count == last_vsync_frame_count) {
        video_canvas_refresh_all(active_canvas);
    }

    last_vsync_frame_count = published_frame_count;
}

void video_canvas_resize(struct video_canvas_s *canvas, char resize_canvas)
{
    (void)resize_canvas;

    if (canvas == NULL || canvas->draw_buffer == NULL || canvas->videoconfig == NULL) {
        return;
    }

    sync_render_config_from_cap(canvas);

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
