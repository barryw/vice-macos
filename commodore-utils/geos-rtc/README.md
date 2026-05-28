# mac VICE GEOS RTC

Tiny GEOS auto-exec drivers for the VICE userport DS1307 real-time clock.

Build:

```sh
make
```

Outputs land in `build/`:

- `macvice-rtc64.prg`
- `macvice-rtc128.prg`
- matching `.grc` metadata files

Package either PRG with the mac VICE disk editor's GEOS Package Assistant, or install it directly onto a GEOS disk image from the assistant. The driver expects VICE's DS1307 userport RTC device to be enabled before GEOS boots.
