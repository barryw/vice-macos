/*
 * kbd.c - Native macOS keyboard backend.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include <stdio.h>
#include <string.h>

#include "kbd.h"
#include "keyboard.h"
#include "keymap.h"

typedef struct macos_keysym_s {
    const char *name;
    signed long symbol;
} macos_keysym_t;

/*
 * VICE's symbolic keymaps already use the same key symbol namespace as GDK/X11.
 * The Swift/AppKit frontend translates native NSEvents into these stable
 * symbols before they enter the emulator.
 */
static const macos_keysym_t macos_keysyms[] = {
    { "BackSpace", 0xff08 },
    { "Tab", 0xff09 },
    { "ISO_Left_Tab", 0xfe20 },
    { "Return", 0xff0d },
    { "Escape", 0xff1b },
    { "Delete", 0xffff },
    { "Insert", 0xff63 },
    { "Home", 0xff50 },
    { "Left", 0xff51 },
    { "Up", 0xff52 },
    { "Right", 0xff53 },
    { "Down", 0xff54 },
    { "Page_Up", 0xff55 },
    { "Prior", 0xff55 },
    { "Page_Down", 0xff56 },
    { "End", 0xff57 },
    { "Print", 0xff61 },
    { "Scroll_Lock", 0xff14 },
    { "Sys_Req", 0xff15 },
    { "Num_Lock", 0xff7f },
    { "Caps_Lock", 0xffe5 },
    { "Shift_L", 0xffe1 },
    { "Shift_R", 0xffe2 },
    { "Control_L", 0xffe3 },
    { "F1", 0xffbe },
    { "F2", 0xffbf },
    { "F3", 0xffc0 },
    { "F4", 0xffc1 },
    { "F5", 0xffc2 },
    { "F6", 0xffc3 },
    { "F7", 0xffc4 },
    { "F8", 0xffc5 },
    { "F9", 0xffc6 },
    { "F10", 0xffc7 },
    { "F11", 0xffc8 },
    { "F12", 0xffc9 },
    { "KP_F1", 0xff91 },
    { "KP_F2", 0xff92 },
    { "KP_F3", 0xff93 },
    { "KP_F4", 0xff94 },
    { "KP_Delete", 0xff9f },
    { "KP_Multiply", 0xffaa },
    { "KP_Add", 0xffab },
    { "KP_Subtract", 0xffad },
    { "KP_Decimal", 0xffae },
    { "KP_Divide", 0xffaf },
    { "KP_0", 0xffb0 },
    { "KP_1", 0xffb1 },
    { "KP_2", 0xffb2 },
    { "KP_3", 0xffb3 },
    { "KP_4", 0xffb4 },
    { "KP_5", 0xffb5 },
    { "KP_6", 0xffb6 },
    { "KP_7", 0xffb7 },
    { "KP_8", 0xffb8 },
    { "KP_9", 0xffb9 },
    { "KP_Enter", 0xff8d },
    { "space", ' ' },
    { "exclam", '!' },
    { "quotedbl", '"' },
    { "numbersign", '#' },
    { "dollar", '$' },
    { "percent", '%' },
    { "ampersand", '&' },
    { "apostrophe", '\'' },
    { "parenleft", '(' },
    { "parenright", ')' },
    { "asterisk", '*' },
    { "plus", '+' },
    { "comma", ',' },
    { "minus", '-' },
    { "period", '.' },
    { "slash", '/' },
    { "colon", ':' },
    { "semicolon", ';' },
    { "less", '<' },
    { "equal", '=' },
    { "greater", '>' },
    { "question", '?' },
    { "at", '@' },
    { "bracketleft", '[' },
    { "backslash", '\\' },
    { "bracketright", ']' },
    { "asciicircum", '^' },
    { "underscore", '_' },
    { "grave", '`' },
    { "braceleft", '{' },
    { "bar", '|' },
    { "braceright", '}' },
    { "asciitilde", '~' },
    { "sterling", 0x00a3 },
    { "dead_grave", 0xfe50 },
    { "dead_acute", 0xfe51 },
    { "dead_circumflex", 0xfe52 },
    { "dead_tilde", 0xfe53 },
    { "dead_perispomeni", 0xfe53 },
    { "dead_diaeresis", 0xfe57 },
    { NULL, 0 }
};

void kbd_arch_init(void)
{
}

void kbd_arch_shutdown(void)
{
}

int kbd_arch_get_host_mapping(void)
{
    return KBD_MAPPING_US;
}

signed long kbd_arch_keyname_to_keynum(char *keyname)
{
    const macos_keysym_t *entry;

    if (keyname == NULL || keyname[0] == '\0') {
        return -1;
    }

    if (keyname[1] == '\0') {
        return (unsigned char)keyname[0];
    }

    for (entry = macos_keysyms; entry->name != NULL; entry++) {
        if (strcmp(entry->name, keyname) == 0) {
            return entry->symbol;
        }
    }

    return -1;
}

const char *kbd_arch_keynum_to_keyname(signed long keynum)
{
    const macos_keysym_t *entry;
    static char keyname[2];
    static char numeric_keyname[24];

    if (keynum >= 0x20 && keynum <= 0x7e) {
        keyname[0] = (char)keynum;
        keyname[1] = '\0';
        return keyname;
    }

    for (entry = macos_keysyms; entry->name != NULL; entry++) {
        if (entry->symbol == keynum) {
            return entry->name;
        }
    }

    snprintf(numeric_keyname, sizeof(numeric_keyname), "%ld", keynum);
    return numeric_keyname;
}

void kbd_initialize_numpad_joykeys(int *joykeys)
{
    joykeys[0] = (int)kbd_arch_keyname_to_keynum("KP_0");
    joykeys[1] = (int)kbd_arch_keyname_to_keynum("KP_1");
    joykeys[2] = (int)kbd_arch_keyname_to_keynum("KP_2");
    joykeys[3] = (int)kbd_arch_keyname_to_keynum("KP_3");
    joykeys[4] = (int)kbd_arch_keyname_to_keynum("KP_4");
    joykeys[5] = (int)kbd_arch_keyname_to_keynum("KP_6");
    joykeys[6] = (int)kbd_arch_keyname_to_keynum("KP_7");
    joykeys[7] = (int)kbd_arch_keyname_to_keynum("KP_8");
    joykeys[8] = (int)kbd_arch_keyname_to_keynum("KP_9");
    joykeys[9] = (int)kbd_arch_keyname_to_keynum("KP_Decimal");
    joykeys[10] = (int)kbd_arch_keyname_to_keynum("KP_Enter");
}
