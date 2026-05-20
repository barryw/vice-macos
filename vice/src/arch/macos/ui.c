/*
 * ui.c - Native macOS UI bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdarg.h>
#include <stdbool.h>

#include "archdep.h"
#include "archdep_usleep.h"
#include "cmdline.h"
#include "fullscreen.h"
#include "interrupt.h"
#include "lib.h"
#include "log.h"
#include "machine.h"
#include "resources.h"
#include "sound.h"
#include "ui.h"
#include "uiapi.h"
#include "vicemacbridge.h"
#include "videoarch.h"
#include "vsync.h"

static const cmdline_option_t cmdline_options_common[] =
{
    CMDLINE_LIST_END
};

static int is_paused = 0;
static int save_resources_on_exit = 0;

static int set_save_resources_on_exit(int val, void *param)
{
    (void)param;

    save_resources_on_exit = val ? 1 : 0;
    return 0;
}

static resource_int_t resources_int[] = {
    { "SaveResourcesOnExit", 0, RES_EVENT_NO, NULL,
      &save_resources_on_exit, set_save_resources_on_exit, NULL },
    RESOURCE_INT_LIST_END
};

void fullscreen_capability(struct cap_fullscreen_s *cap_fullscreen)
{
    (void)cap_fullscreen;
}

int ui_cmdline_options_init(void)
{
    return cmdline_register_options(cmdline_options_common);
}

char *ui_get_file(const char *format, ...)
{
    char *buffer;
    va_list args;

    va_start(args, format);
    buffer = lib_mvsprintf(format, args);
    va_end(args);

    log_warning(LOG_DEFAULT, "Native macOS file request is not wired yet: %s", buffer);
    lib_free(buffer);

    return NULL;
}

void ui_init_with_args(int *argc, char **argv)
{
    (void)argc;
    (void)argv;

    log_verbose(LOG_DEFAULT, "Initialising native macOS ui bridge");
}

int ui_init(void)
{
    log_verbose(LOG_DEFAULT, "Initialising native macOS ui");
    return 0;
}

int ui_init_finalize(void)
{
    return 0;
}

ui_jam_action_t ui_jam_dialog(const char *format, ...)
{
    char *buffer;
    va_list args;

    va_start(args, format);
    buffer = lib_mvsprintf(format, args);
    va_end(args);

    log_warning(LOG_DEFAULT, "%s", buffer);
    lib_free(buffer);

    return MACHINE_JAM_ACTION_QUIT;
}

int ui_resources_init(void)
{
    return resources_register_int(resources_int);
}

void ui_resources_shutdown(void)
{
}

void ui_shutdown(void)
{
}

void ui_dispatch_events(void)
{
    vicemac_dispatch_queued_events();
}

int ui_extend_image_dialog(void)
{
    return 0;
}

void ui_error(const char *format, ...)
{
    char *buffer;
    va_list args;

    va_start(args, format);
    buffer = lib_mvsprintf(format, args);
    va_end(args);

    log_error(LOG_DEFAULT, "VICE Error: %s", buffer);
    lib_free(buffer);
}

void ui_message(const char *format, ...)
{
    char *buffer;
    va_list args;

    va_start(args, format);
    buffer = lib_mvsprintf(format, args);
    va_end(args);

    log_message(LOG_DEFAULT, "VICE Message: %s", buffer);
    lib_free(buffer);
}

bool ui_pause_loop_iteration(void)
{
    ui_dispatch_events();
    archdep_usleep(10000);

    return is_paused;
}

static void pause_trap(uint16_t addr, void *data)
{
    (void)addr;
    (void)data;

    vsync_suspend_speed_eval();
    sound_suspend();

    while (ui_pause_loop_iteration()) {
    }
}

int ui_pause_active(void)
{
    return is_paused;
}

void ui_pause_enable(void)
{
    if (!ui_pause_active()) {
        is_paused = 1;
        interrupt_maincpu_trigger_trap(pause_trap, 0);
    }
}

void ui_pause_disable(void)
{
    if (ui_pause_active()) {
        is_paused = 0;
    }
}

void ui_pause_toggle(void)
{
    if (ui_pause_active()) {
        ui_pause_disable();
    } else {
        ui_pause_enable();
    }
}

void ui_update_lightpen(void)
{
}

void ui_enable_crt_controls(int enabled)
{
    (void)enabled;
}

void ui_enable_mixer_controls(int enabled)
{
    (void)enabled;
}

void arch_ui_activate(void)
{
}

video_canvas_t *ui_get_active_canvas(void)
{
    return vicemac_video_active_canvas();
}
