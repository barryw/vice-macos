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
