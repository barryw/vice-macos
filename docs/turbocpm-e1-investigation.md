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

## RESOLVED (2026-07-20 session 2): three stacked causes, fix landed

The bridge diagnostics below were implemented (env-gated
`VICEMAC_TURBO_DIAG=1` → `/tmp/vicemac-bridge-diag.log`, `[TurboDiag]`
prefix; instrumented: z80.c IN/OUT dispatch, z80mem.c unconnected-I/O,
c128fastiec.c both directions, cia1571d.c store_sdr,
serial-iec-device.c state transitions, vicemacbridge.c dispatch
queues). One session of runs took it from "app-only mystery" to root
cause:

1. **The kit "pass" evidence was vacuous.**
   `testRuntimeC128NTSCBootsTurboCPMWriteProtected` polled `$F407 != 0`
   (bank 4). VICE's RAM init pattern leaves `$F407=$FF`, so the test
   "passed" ~0.5s after reset without any boot — proven by a control
   test (no disk attached, `$F407` still `$FF` at 1/3/6s). Every prior
   green run of that test (and its "variants") proved nothing. The
   doc's earlier conclusion "only the live interactive process
   reproduces it" was an artifact of this. The test now uses the
   prompt-test image + `$2000/$AA/$Ex` semantics like the other boot
   tests — and with that, **E1 reproduces headless**, same 15s failure
   as the app.

2. **Bisect: the trigger is `-busdevice4`** (true IEC emulation of
   printer 4; app argv carries it, GTK config and the old kit tests
   don't). NTSC/PAL, warp, sound, mouse, frame source, read-only
   attach, drives 9-11: all innocent. Minimal repro = plain boot +
   `-busdevice4`.

3. **Root cause: two compounding defects in VICE
   `serial/serial-iec-device.c`** (the emulated IEC listener that
   `-busdevice4` puts on the bus). Both fixed, `[TurboCPM]`-marked:

   a) **Tick starvation.** The device's state machine advanced at most
   one state per host `$DD00` access (iecbus conf3 hooks — no alarm).
   The kernal polls `$DD00` constantly under ATN so it always fed
   enough ticks; Turbo CP/M's Z80 holds ATN in ~56ms access-free CPU
   delays, so the device got 2 ticks where the walk needs 3+ and froze
   in P_PRE1 holding DATA (trace: `iecdev4 state=0->1`, frozen 3.4M
   cycles until the Z80's 65536-poll loop expired → E1 on frame 1).
   Fixed twice over: the listener switch now walks every transition
   the current bus snapshot satisfies (bounded — adjacent states need
   opposite CLK levels or fresh timeouts), and a 25µs maincpu alarm
   ticks the state machine whenever any serial IEC device is enabled,
   like real hardware that watches the wires continuously.

   b) **Edge-vs-level ready-to-send.** With (a) fixed, ATN frame 1
   (LISTEN $28, bit-banged) completed and frame 2 still froze: Turbo
   CP/M asserts ATN for frame 2 **with CLK already released** and
   sends the command byte over fast serial — burst style. P_PRE1
   insisted on *observing CLK low* before P_PRE2 would accept a rising
   flank, an edge requirement no real listener has: a real device
   answers the ready-to-send *level* after its ATN ack. P_PRE1 now
   treats CLK-already-high (post the 100µs P_PRE0 glitch guard) as
   ready-to-send and answers ready-for-data immediately, exactly as
   P_PRE2 would on the flank.

   Verified after the fix: minimal repro (plain boot + `-busdevice4`)
   boots; the full app stack (NTSC, sound, mouse, frame source, whole
   argv tail, drives 9-11, write-protected attach) boots in 33s
   realtime; plain PAL/warp and DCR regressions still pass; full
   MacVICEKit suite 58 tests 0 failures.

Autopsy reread under the new theory: DISK_STATUS=$FF "drive answered
nothing" was right for the wrong drive — drive 8 was healthy; the
DATA line the Z80 was watching was held by the emulated *printer*.

**Barry's in-app confirmation** (instrumentation stays until then, it
is env-gated and free when off): rebuild the VICE Mac C128 scheme (the
runtime dylibs in BuildProducts are already rebuilt with the fix),
then launch from a terminal with
`VICEMAC_TURBO_DIAG=1 /path/to/ViceMac.app/Contents/MacOS/ViceMac`,
attach the D71, soft reset. Expected: CP/M boots where it used to E1.
If anything still fails, `/tmp/vicemac-bridge-diag.log` now names the
stuck component directly (`docs/turbodiag-diff.sh good.log bad.log`
diffs two traces event-by-event). After confirmation: strip
`turbodiag.h` and its call sites (grep `turbodiag`), keep the
`[TurboCPM]` fixes and the repaired kit tests.

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
