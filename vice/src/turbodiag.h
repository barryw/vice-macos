/*
 * turbodiag.h - Temporary TurboCPM E1 bridge diagnostics.
 *
 * Env-gated tracing for the app-only burst-init E1 failure
 * (docs/turbocpm-e1-investigation.md). Set VICEMAC_TURBO_DIAG=1 to
 * append [TurboDiag] lines to /tmp/vicemac-bridge-diag.log, each
 * stamped with maincpu_clk. Header-only so no Makefile.am changes;
 * every including TU shares the log file via O_APPEND.
 *
 * Remove after the E1 root cause is fixed.
 */

#ifndef VICE_TURBODIAG_H
#define VICE_TURBODIAG_H

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "types.h"

extern CLOCK maincpu_clk;

#define TURBODIAG_LOG_PATH "/tmp/vicemac-bridge-diag.log"
/* per-TU cap so a runaway loop cannot fill the disk */
#define TURBODIAG_MAX_LINES 200000L

static FILE *turbodiag_file = NULL;
static int turbodiag_enabled_state = -1;
static long turbodiag_line_count = 0;

#if defined(__GNUC__) || defined(__clang__)
__attribute__((unused))
#endif
static int turbodiag_enabled(void)
{
    if (turbodiag_enabled_state < 0) {
        const char *env = getenv("VICEMAC_TURBO_DIAG");

        turbodiag_enabled_state = (env != NULL && env[0] != '\0' && env[0] != '0');
        if (turbodiag_enabled_state) {
            turbodiag_file = fopen(TURBODIAG_LOG_PATH, "a");
            if (turbodiag_file == NULL) {
                turbodiag_enabled_state = 0;
            }
        }
    }
    return turbodiag_enabled_state;
}

#if defined(__GNUC__) || defined(__clang__)
__attribute__((format(printf, 1, 2), unused))
#endif
static void turbodiag_log(const char *fmt, ...)
{
    va_list ap;

    if (!turbodiag_enabled() || turbodiag_line_count >= TURBODIAG_MAX_LINES) {
        return;
    }
    turbodiag_line_count++;
    fprintf(turbodiag_file, "[TurboDiag] clk=%llu ", (unsigned long long)maincpu_clk);
    va_start(ap, fmt);
    vfprintf(turbodiag_file, fmt, ap);
    va_end(ap);
    fputc('\n', turbodiag_file);
    fflush(turbodiag_file);
}

#endif
