/*
 * hotkeys.c - Native macOS hotkey bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdint.h>

#include "uiactions.h"
#include "uiapi.h"

uint32_t ui_hotkeys_arch_keysym_to_arch(uint32_t vice_keysym)
{
    return vice_keysym;
}

uint32_t ui_hotkeys_arch_keysym_from_arch(uint32_t arch_keysym)
{
    return arch_keysym;
}

uint32_t ui_hotkeys_arch_modifier_to_arch(uint32_t vice_mod)
{
    return vice_mod;
}

uint32_t ui_hotkeys_arch_modifier_from_arch(uint32_t arch_mod)
{
    return arch_mod;
}

uint32_t ui_hotkeys_arch_modmask_to_arch(uint32_t vice_modmask)
{
    return vice_modmask;
}

uint32_t ui_hotkeys_arch_modmask_from_arch(uint32_t arch_modmask)
{
    return arch_modmask;
}

void ui_hotkeys_arch_install_by_map(ui_action_map_t *map)
{
    (void)map;
}

void ui_hotkeys_arch_remove_by_map(ui_action_map_t *map)
{
    (void)map;
}

void ui_hotkeys_arch_init(void)
{
}

void ui_hotkeys_arch_shutdown(void)
{
}
