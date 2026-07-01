/*
 * kbd.h - Native macOS keyboard backend.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#ifndef VICE_MACOS_KBD_H
#define VICE_MACOS_KBD_H

void kbd_arch_init(void);
void kbd_arch_shutdown(void);
int kbd_arch_get_host_mapping(void);
void kbd_initialize_numpad_joykeys(int *joykeys);

#define KBD_PORT_PREFIX "macos"

signed long kbd_arch_keyname_to_keynum(char *keyname);
const char *kbd_arch_keynum_to_keyname(signed long keynum);

#endif
