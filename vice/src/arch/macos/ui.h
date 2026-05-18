/*
 * ui.h - Native macOS UI bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#ifndef VICE_UI_H
#define VICE_UI_H

#include "vice.h"

#include "palette.h"
#include "videoarch.h"

enum {
    PRIMARY_WINDOW,
    SECONDARY_WINDOW,
    MONITOR_WINDOW
};

void ui_dispatch_events(void);

int ui_pause_active(void);
void ui_pause_enable(void);
bool ui_pause_loop_iteration(void);
void ui_pause_disable(void);
void ui_pause_toggle(void);

void ui_update_lightpen(void);
void ui_enable_crt_controls(int enabled);
void ui_enable_mixer_controls(int enabled);

video_canvas_t *ui_get_active_canvas(void);

#endif
