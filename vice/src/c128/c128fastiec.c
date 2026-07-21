/*
 * c128fastiec.c - Fast IEC bus handling for the C128.
 *
 * Written by
 *  Andreas Boose <viceteam@t-online.de>
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *  02111-1307  USA.
 *
 */

#include "vice.h"

#include "c128fastiec.h"
#include "c64.h"
#include "cia.h"
#include "via.h"
#include "drive.h"
#include "drivetypes.h"
#include "iecdrive.h"
#include "maincpu.h"
#include "types.h"
#include "drive/iec/cmdhd.h"

/* TurboCPM E1 diagnostics — see docs/turbocpm-e1-investigation.md. */
#include "turbodiag.h"

static int fast_cpu_direction, fast_drive_direction[NUM_DISK_UNITS];
int burst_mod = 0;

void c128fastiec_init(void)
{
    unsigned int dnr;

    fast_cpu_direction = 0;

    for (dnr = 0; dnr < NUM_DISK_UNITS; dnr++) {
        fast_drive_direction[dnr] = 1;
    }
}

void c128fastiec_fast_cpu_write(uint8_t data)
{
    unsigned int dnr;

    turbodiag_log("host-sdr-write $%02X dir=%d", data, fast_cpu_direction);

    if (fast_cpu_direction) {
        for (dnr = 0; dnr < NUM_DISK_UNITS; dnr++) {
            diskunit_context_t *unit = diskunit_context[dnr];

            if (unit->enable) {
                drive_catch_up_one_hook(unit, maincpu_clk);
                turbodiag_log("host-sdr-write -> unit%u type=%u", dnr + 8, unit->type);
                switch (unit->type) {
                    case DRIVE_TYPE_1570:
                    case DRIVE_TYPE_1571:
                    case DRIVE_TYPE_1571CR:
                        ciacore_set_sdr(unit->cia1571, data);
                        break;
                    case DRIVE_TYPE_1581:
                        ciacore_set_sdr(unit->cia1581, data);
                        break;
                    case DRIVE_TYPE_2000:
                    case DRIVE_TYPE_4000:
                        viacore_set_sr(unit->via4000, data);
                        break;
                    case DRIVE_TYPE_CMDHD:
                        viacore_set_sr(unit->cmdhd->via10, data);
                        break;
                }
            }
        }
    }
}

void iec_fast_drive_write(uint8_t data, unsigned int dnr)
{
    turbodiag_log("drive%u-sdr-write $%02X dir=%d", dnr + 8, data,
                  fast_drive_direction[dnr]);
    if (fast_drive_direction[dnr]) {
        ciacore_set_sdr(machine_context.cia1, data);
    }
}

void c128fastiec_fast_cpu_direction(int direction)
{
    /* 0: input */
    if (direction != fast_cpu_direction) {
        turbodiag_log("host-fast-dir %d", direction);
    }
    fast_cpu_direction = direction;
}

void iec_fast_drive_direction(int direction, unsigned int dnr)
{
    /* 0: input */
    if (direction != fast_drive_direction[dnr]) {
        turbodiag_log("drive%u-fast-dir %d", dnr + 8, direction);
    }
    fast_drive_direction[dnr] = direction;
}

void c64fastiec_fast_cpu_write(uint8_t data)
{
}
