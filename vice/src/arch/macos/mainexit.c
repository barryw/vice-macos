/*
 * mainexit.c - Native macOS emulator shutdown hook.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include "log.h"
#include "machine.h"

void main_exit(void)
{
    log_message(LOG_DEFAULT, "\nExiting...");
    machine_shutdown();
}
