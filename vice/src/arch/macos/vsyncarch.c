/*
 * vsyncarch.c - End-of-frame handling for the native macOS bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include "joystick.h"
#include "ui.h"
#include "videoarch.h"
#include "vsyncapi.h"

static int pause_pending = 0;

void vsyncarch_presync(void)
{
    ui_dispatch_events();
    ui_update_lightpen();
    joystick();
}

void vsyncarch_postsync(void)
{
    vicemac_video_refresh_if_idle();

    if (pause_pending) {
        ui_pause_enable();
        pause_pending = 0;
    }
}

void vsyncarch_advance_frame(void)
{
    ui_pause_disable();
    pause_pending = 1;
}
