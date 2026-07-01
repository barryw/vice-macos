/*
 * joystick.c - Native macOS joystick bridge.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdint.h>

#include "joystick.h"

void joystick_arch_init(void)
{
}

void joystick_arch_shutdown(void)
{
}

void joystick_ui_event(void *input, joystick_input_t type, int32_t value)
{
    (void)input;
    (void)type;
    (void)value;
}
