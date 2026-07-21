# TurboCPM E1 in the ViceMac app — live-process investigation (2026-07-20)

Symptom: booting the (fixed, WP-tolerant) TurboCPM D71 in the ViceMac
C128 app dies at burst-init E1. The identical dylib, arguments,
resources, ROMs, disk, attach mode (-1/real drive) and soft reset pass
in MacVICEKit live tests — including variants with NTSC, read-only
attach, idle drive 9, realtime+coreaudio sound, mouse+keymap resources,
the full app argument tail, and an attached, drained
MacVICEFrameSource. GTK x128 boots the same disk with both drives
populated.

lldb autopsy of the frozen failing app (Xcode console):
- Z80 pc=$FFED (handed back after painting E1), machine at BASIC.
- DISK_STATUS=$FF, DISK_DETAIL=0: the drive answered nothing at all —
  the Z80's very first slow-bus command or the INQUIRE burst byte
  timed out, twice (init retries).
- Live resources at failure are correct: Drive8TrueEmulation=1,
  FileSystemDevice8=0, Drive8Type=1571, TrapDevice8=0.
- Drive 8: enabled, idling at ROM $FF25, half-track 2 (track 1: it
  served the kernal chain load seconds earlier over slow serial).
- iecbus: cpu_bus=$D0, drv_bus[8]=$40 post-failure.
- Embedded-framework ROMs byte-identical to vice/data and
  /usr/local/share/vice.

Every settings path was audited: Storage pane -> suffixed per-machine
defaults key -> EmulatorDefaults -> launch argv verified byte-for-byte
in the captured app log; legacy unsuffixed store is x64sc-only.

Conclusion: only the live interactive process reproduces it. Prime
remaining suspect: real HID input injection at boot (a physical game
controller on port 2 / 1351 mouse on port 1 feeding
joystick/mouse values the headless runs never see), or another
app-only runtime feed. Next step is a diagnostic app build that logs,
during the first 15 s after reset: joystick_set_value/mouse deltas,
z80 port I/O to $DC0C/$DD00, and Drive8 resource writes — then one
user reproduction names the divergence.

Workarounds meanwhile: GTK x128 and the GTK MacVICE bundle boot the
disk fine (HARD_WON notes apply); turbocpm testing is unblocked there.

## AUTHORIZED NEXT STEP (Barry, 2026-07-20): bridge diagnostics

Barry has explicitly authorized adding whatever diagnostics the bridge
needs. Plan for the next session — implement, reproduce once, decode:

1. Env-gated tracing (`VICEMAC_TURBO_DIAG=1`, log to
   `/tmp/vicemac-bridge-diag.log`, `[TurboDiag]` prefix, every line
   stamped with `maincpu_clk`), covering the first ~20 s after any
   machine reset:
   - Z80 port I/O to $DD00-$DD0F (CIA2/IEC), $DC0C-$DC0F (CIA1
     SDR/ICR/CRA), and $D505 (MMU), plus the live C128 `mem_config` at
     each access — instrument the Z80 I/O dispatch in
     `vice/src/c128/z80mem.c` (this is where silent gating would hide).
   - Drive 8 side: 1571 CIA SDR stores and fast-serial dispatch
     (`vice/src/drive/iec/cia1571d.c` store_sdr path) — proves whether
     the command ever reached the drive and whether its answer left.
   - Every `queueResourceInt/String` and reset/attach dispatch in
     `vice/src/arch/macos/vicemacbridge.c` (timestamps expose ordering
     races between live resource sets, attach, and reset).
   - Every joystick/mouse injection call.
2. Reproduce: app run, attach + reset, E1, quit. Then run the SAME
   instrumented core through the passing MacVICEKit test
   (`testRuntimeC128NTSCBootsTurboCPMWriteProtected`) and diff the two
   traces at first divergence. The kit run boots in ~5 s realtime, so
   the traces align from reset.
3. Decode table:
   - App trace missing the Z80 $DD00 OUTs -> Z80 I/O routing/gating
     broken only in-app; chase `mem_config` state at the access.
   - OUTs present, drive CIA silent -> drive-side dispatch/scheduling;
     chase diskunit clock sync in the app run.
   - Both present, answer sent, host never sees it -> host CIA1
     SDR/ICR delivery; chase cross-thread stalls between the OUT and
     the ICR poll.
4. Evidence base (all above in this doc): resources/ROMs/argv/disk
   proven identical and passing headless; live autopsy shows
   DISK_STATUS=$FF, drive idle at $FF25, Z80 parked at $FFED.
   Remove the instrumentation after the fix; keep the kit regression.
