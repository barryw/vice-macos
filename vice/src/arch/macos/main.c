/*
 * main.c - Native macOS standalone startup.
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 */

#include "vice.h"

#include "archdep_program_path.h"
#include "main.h"

int main(int argc, char **argv)
{
    if (argc > 0) {
        archdep_program_path_set_argv0(argv[0]);
    }

    return main_program(argc, argv);
}
