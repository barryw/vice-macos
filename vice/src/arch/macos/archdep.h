/** \file   archdep.h
 * \brief   Miscellaneous system-specific stuff for the native macOS bridge.
 */

/*
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

#ifndef VICE_ARCHDEP_H
#define VICE_ARCHDEP_H

/* XXX: do NOT include <stdbool.h>, causes bugs in monitor code */
#include "vice.h"
#include "sound.h"

/*
 * The native macOS frontend presents with Metal, so VICE should render one
 * logical emulator pixel per source pixel. SwiftUI and Metal own window and
 * display scaling.
 */
#define ARCHDEP_VICII_DSIZE   0
#define ARCHDEP_VICII_DSCAN   0
#define ARCHDEP_VDC_DSIZE     0
#define ARCHDEP_VDC_DSCAN     0
#define ARCHDEP_VIC_DSIZE     0
#define ARCHDEP_VIC_DSCAN     0
#define ARCHDEP_CRTC_DSIZE    0
#define ARCHDEP_CRTC_DSCAN    0
#define ARCHDEP_TED_DSIZE     0
#define ARCHDEP_TED_DSCAN     0

/* No key symcode. */
#define ARCHDEP_KEYBOARD_SYM_NONE 0

#define ARCHDEP_SOUND_OUTPUT_MODE SOUND_OUTPUT_SYSTEM
#define ARCHDEP_SEPERATE_MONITOR_WINDOW
#define ARCHDEP_MOUSE_ENABLE_DEFAULT 0
#define ARCHDEP_SHOW_STATUSBAR_FACTORY 0

#ifdef UNIX_COMPILE
#include "archdep_unix.h"
#endif

#ifdef WINDOWS_COMPILE
#include "archdep_win32.h"
#endif

void  archdep_user_config_path_free(void);
char *archdep_get_vice_datadir(void);
char *archdep_get_vice_docsdir(void);
int   archdep_register_cbmfont(void);
void  archdep_unregister_cbmfont(void);

#endif
