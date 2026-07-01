/*
 * videoarch.h - Native macOS graphics bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#ifndef VICE_VIDEOARCH_H
#define VICE_VIDEOARCH_H

#include "archdep.h"
#include "video.h"

typedef struct video_canvas_s {

    /** Nonzero if it is safe to access other members of the structure. */
    unsigned int initialized;

    /** Nonzero if the structure has been fully realized. */
    unsigned int created;

    /** Rendering configuration as seen by the emulator core. */
    struct video_render_config_s *videoconfig;

    /** Tracks color encoding changes. */
    int crt_type;

    /** Drawing buffer as seen by the emulator core. */
    struct draw_buffer_s *draw_buffer;

    /** Display viewport as seen by the emulator core. */
    struct viewport_s *viewport;

    /** Machine screen geometry as seen by the emulator core. */
    struct geometry_s *geometry;

    /** Color palette for translating display results into window colors. */
    struct palette_s *palette;

    /** Used to limit frame rate under warp. */
    tick_t warp_next_render_tick;
} video_canvas_t;

typedef struct vice_renderer_backend_s {
} vice_renderer_backend_t;

void vicemac_video_refresh_if_idle(void);
video_canvas_t *vicemac_video_active_canvas(void);

#endif
