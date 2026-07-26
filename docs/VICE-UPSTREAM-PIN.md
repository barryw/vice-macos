# VICE upstream pin

## Policy

`vice/` is pinned to an **upstream VICE release tag**. We do not build releases
from upstream trunk (`upstream/main`).

The pin is recorded in [`VICE_UPSTREAM_RELEASE`](../VICE_UPSTREAM_RELEASE) at the
repo root (shell-sourceable), currently:

| Field | Value |
| --- | --- |
| `VICE_UPSTREAM_RELEASE_TAG` | `3.10.0` |
| `VICE_UPSTREAM_RELEASE_COMMIT` | `4d283a2e7dd59b7e378524878e81ecc7826b700c` |

Upstream tags releases each Christmas (`3.8.0` 2023-12-24, `3.9.0` 2024-12-24,
`3.10.0` 2025-12-24), so expect the pin to move roughly once a year.

### Why

The emulator version reported by the app comes from `vice/configure.ac`
(`macos/scripts/compute-vicemac-version.sh`). Upstream does not bump that value
between releases, so building from trunk shipped DMGs labelled `3.10.0` that
actually contained thousands of unreleased trunk commits — a version string that
was not true, and emulator changes no user had ever seen in a release.

### Consequences

- No build step fetches `upstream/main`. `ci-prepare.sh`, the packaging scripts
  and `publish-github-release.sh` all read `VICE_UPSTREAM_RELEASE` instead.
- `VICEUpstreamGitSHA` (app `Info.plist`, runtime manifest) is the pinned release
  commit, not a trunk merge-base.
- Release notes classify a commit as _upstream VICE_ when it is an ancestor of
  the pinned release commit.
- Upstream fixes made after the pinned release are **not** picked up
  automatically. Backport them deliberately (see below).

## Our delta on top of the release

Everything under `vice/src/arch/macos/` is ours (the macOS arch port, including
`vicemacbridge.c`). On top of that we patch these upstream files:

| Area | Files | Why |
| --- | --- | --- |
| Build wiring | `configure.ac`, `src/Makefile.am`, `src/arch/Makefile.am`, `src/arch/shared/Makefile.am`, `data/*/Makefile.am` | build the `macos` arch, install macOS keymaps |
| Upstream fix backports | `src/arch/shared/macOS-launcher.c` | missing `<mach-o/dyld.h>`; fixed upstream after 3.10.0 |
| SID visualizer | `src/resid/sid.{h,cc}`, `src/sid/resid.cc`, `src/sid/sid.c` | per-voice sample tap feeding the VSID visualizer |
| Host filesystem device | `src/fsdevice/*` | macOS filename/flush/read behaviour |
| IEC / serial | `src/serial/serial-iec-device.c` | ATN handshake fix |
| Misc | `src/sound.c`, `src/log.c`, `src/autostart-prg.c`, `src/joyport/mouse.c`, `src/arch/headless/mousedrv.c`, `src/core/rtc/ds1307.*`, `src/userport/userport_rtc_ds1307.*`, `src/rs232drv/rs232net.c`, `src/c128/c128-cmdline-options.c`, `src/c1541-stubs.c` | bridge hooks and macOS-specific behaviour |

`git diff <VICE_UPSTREAM_RELEASE_COMMIT> -- vice/` is always the authoritative
list.

### Not backported: ReSID-FP

Upstream added the ReSID-FP engine (`SID_ENGINE_RESIDFP`, engine `8`, vendored
`src/lib/libresidfp`) to trunk **after** 3.10.0 — it has never shipped in a VICE
release. We deliberately do not vendor it. VSID uses `-sidengine 1` (ReSID) and
the voice visualizer taps ReSID instead. ReSID-FP becomes available for free when
the pin moves to the release that ships it.

## Moving the pin to a new upstream release

1. Fetch the tag: `git fetch upstream tag <X.Y.Z>`.
2. Capture our delta: `git diff --binary <old pinned commit> HEAD -- vice/ > /tmp/port.patch`.
3. Reset the tree: `rm -rf vice && git checkout <X.Y.Z> -- vice && git add -A vice`.
4. Reapply: `git apply --3way /tmp/port.patch`, then resolve any conflicts.
5. Update `VICE_UPSTREAM_RELEASE` (tag **and** commit) and the table above.
6. Rebuild and test: `macos/scripts/prepare-vicemac-runtime.sh` then
   `macos/scripts/ci-test.sh`.

Do **not** commit generated files into `vice/`. `mon_lex.c`, `mon_parse.[ch]`,
`src/resid/wave*.h`, `src/c64/psiddrv.[ho65]` and `__.SYMDEF SORTED` had leaked
into the tree from in-tree builds; the build generates them in its own build
directory.

## Backporting an upstream fix

Cherry-pick the specific upstream change into `vice/`, keep it as small as
possible, and add a row to the "Upstream fix backports" table above so the next
pin move knows the patch can be dropped once the release contains it.
