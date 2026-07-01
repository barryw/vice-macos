/*
 * vsidui.c - Native macOS VSID UI bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdio.h>
#include <string.h>

#include "hvsc.h"
#include "vicemacbridge.h"
#include "vsidui.h"

static vicemac_vsid_state_t vsid_state;

static void copy_text(char *destination, size_t capacity, const char *source)
{
    if (destination == 0 || capacity == 0) {
        return;
    }

    if (source == 0) {
        destination[0] = '\0';
        return;
    }

    snprintf(destination, capacity, "%s", source);
}

static void publish_state(void)
{
    vicemac_publish_vsid_state(&vsid_state);
}

void vsid_ui_close(void)
{
    hvsc_exit();
}

void vsid_ui_display_author(const char *author)
{
    copy_text(vsid_state.author, sizeof(vsid_state.author), author);
    publish_state();
}

void vsid_ui_display_copyright(const char *copyright)
{
    copy_text(vsid_state.copyright, sizeof(vsid_state.copyright), copyright);
    publish_state();
}

void vsid_ui_display_irqtype(const char *irq)
{
    copy_text(vsid_state.irq, sizeof(vsid_state.irq), irq);
    publish_state();
}

void vsid_ui_display_name(const char *name)
{
    copy_text(vsid_state.name, sizeof(vsid_state.name), name);
    publish_state();
}

void vsid_ui_display_nr_of_tunes(int count)
{
    vsid_state.tune_count = count > 0 ? (uint32_t)count : 0U;
    publish_state();
}

void vsid_ui_display_sid_model(int model)
{
    vsid_state.sid_model = model;
    publish_state();
}

void vsid_ui_display_sync(int sync)
{
    vsid_state.sync = sync > 0 ? (uint32_t)sync : 0U;
    publish_state();
}

void vsid_ui_display_time(unsigned int dsec)
{
    vsid_state.deciseconds = dsec;
    publish_state();
}

void vsid_ui_display_tune_nr(int nr)
{
    vsid_state.current_tune = nr > 0 ? (uint32_t)nr : 0U;
    publish_state();
}

void vsid_ui_setdrv(char *driver_info_text)
{
    copy_text(vsid_state.driver_info, sizeof(vsid_state.driver_info), driver_info_text);
    publish_state();
}

void vsid_ui_set_default_tune(int nr)
{
    vsid_state.default_tune = nr > 0 ? (uint32_t)nr : 0U;
    publish_state();
}

void vsid_ui_set_driver_addr(uint16_t addr)
{
    vsid_state.driver_address = addr;
    publish_state();
}

void vsid_ui_set_load_addr(uint16_t addr)
{
    vsid_state.load_address = addr;
    publish_state();
}

void vsid_ui_set_init_addr(uint16_t addr)
{
    vsid_state.init_address = addr;
    publish_state();
}

void vsid_ui_set_play_addr(uint16_t addr)
{
    vsid_state.play_address = addr;
    publish_state();
}

void vsid_ui_set_data_size(uint16_t size)
{
    vsid_state.data_size = size;
    publish_state();
}

int vsid_ui_init(void)
{
    memset(&vsid_state, 0, sizeof(vsid_state));
    publish_state();
    return 0;
}
