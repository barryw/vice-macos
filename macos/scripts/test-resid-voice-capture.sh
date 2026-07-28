#!/usr/bin/env bash
# Verifies the per-voice sample tap we add to ReSID (vice/src/resid/sid.{h,cc}),
# which feeds the VSID voice visualizer.
#
# Self-contained: it generates the two things ReSID needs from configure
# (siddefs.h and the wave*.h sample tables) into a temp dir and compiles the
# vendored sources directly, so it does not care whether, where, or when the
# engine was built.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESID_SRC="$REPO_ROOT/vice/src/resid"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/resid-voice-capture.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

GENERATED_INCLUDE="$work_dir/generated"
mkdir -p "$GENERATED_INCLUDE"

# Same substitutions VICE's configure makes for an Apple Silicon build.
sed \
    -e 's/@RESID_INLINING@/1/' \
    -e 's/@RESID_INLINE@/inline/' \
    -e 's/@RESID_BRANCH_HINTS@/1/' \
    -e 's/@NEW_8580_FILTER@/1/' \
    -e 's/@HAVE_BOOL@/1/' \
    -e 's/@HAVE_BUILTIN_EXPECT@/1/' \
    -e 's/@HAVE_LOG1P@/1/' \
    "$RESID_SRC/siddefs.h.in" >"$GENERATED_INCLUDE/siddefs.h"

# wave*.h are BUILT_SOURCES: samp2src.pl turns each .dat sample table into a header.
for dat in "$RESID_SRC"/wave*.dat; do
    base="$(basename "$dat" .dat)"
    perl "$RESID_SRC/samp2src.pl" "$base" "$dat" "$GENERATED_INCLUDE/$base.h"
done

filter_src="filter8580new.cc"   # matches NEW_8580_FILTER above

cat >"$work_dir/main.cc" <<'EOF'
#include "sid.h"

#include <cstdio>
#include <cstring>

/* Gate voice 1 only. The tap must track that oscillator per sample while the
 * two untouched voices stay put.
 *
 * NOTE: idle voices are not zero — ReSID models the SID powerup envelope
 * counter (0xaa), which reset() deliberately leaves alone, so an ungated voice
 * holds a constant DC value instead. Constant, not silent, is the check, and it
 * only holds after the floating waveform output has decayed, hence the settle
 * clock below. */
int main(void)
{
    const int frames = 512;
    reSID::SID sid;
    reSID::cycle_count delta_t = 985248 / 40; /* ~25ms of PAL cycles */
    short buf[frames];
    short voices[frames * 3];
    int emitted;
    int voice1_min;
    int voice1_max;
    int voice2_changes = 0;
    int voice3_changes = 0;
    int i;

    sid.set_chip_model(reSID::MOS6581);
    if (!sid.set_sampling_parameters(985248, reSID::SAMPLE_FAST, 44100)) {
        fprintf(stderr, "FAIL: could not set sampling parameters\n");
        return 1;
    }
    sid.reset();
    sid.clock(985248 / 5);              /* let floating waveform outputs decay */

    sid.write(0x18, 0x0f);              /* master volume */
    sid.write(0x00, 0x00);              /* voice 1 freq lo */
    sid.write(0x01, 0x20);              /* voice 1 freq hi */
    sid.write(0x05, 0x00);              /* voice 1 attack/decay: fastest */
    sid.write(0x06, 0xf0);              /* voice 1 sustain: max */
    sid.write(0x04, 0x21);              /* voice 1 sawtooth + gate on */

    memset(voices, 0, sizeof(voices));
    sid.set_voice_capture_buffer(voices, 3);
    emitted = sid.clock(delta_t, buf, frames);
    sid.set_voice_capture_buffer(0, 0);

    if (emitted <= 0) {
        fprintf(stderr, "FAIL: no samples emitted\n");
        return 1;
    }

    voice1_min = voices[0];
    voice1_max = voices[0];
    for (i = 0; i < emitted; i++) {
        const int v1 = voices[i * 3];
        if (v1 < voice1_min) {
            voice1_min = v1;
        }
        if (v1 > voice1_max) {
            voice1_max = v1;
        }
        if (i > 0) {
            if (voices[(i * 3) + 1] != voices[((i - 1) * 3) + 1]) {
                voice2_changes++;
            }
            if (voices[(i * 3) + 2] != voices[((i - 1) * 3) + 2]) {
                voice3_changes++;
            }
        }
    }

    /* A gated sawtooth at max sustain must swing, not sit still. */
    if (voice1_max - voice1_min < 1000) {
        fprintf(stderr, "FAIL: gated voice 1 barely moved (min %d, max %d)\n",
                voice1_min, voice1_max);
        return 1;
    }

    if (voice2_changes != 0 || voice3_changes != 0) {
        fprintf(stderr, "FAIL: ungated voices moved (voice 2: %d, voice 3: %d)\n",
                voice2_changes, voice3_changes);
        return 1;
    }

    /* Capture must stay off once the buffer is cleared. */
    memset(voices, 0, sizeof(voices));
    delta_t = 985248 / 40;
    sid.clock(delta_t, buf, frames);
    for (i = 0; i < frames * 3; i++) {
        if (voices[i] != 0) {
            fprintf(stderr, "FAIL: capture wrote after the buffer was cleared\n");
            return 1;
        }
    }

    printf("resid voice capture test passed (%d frames, voice 1 swing %d..%d)\n",
           emitted, voice1_min, voice1_max);
    return 0;
}
EOF

clang++ -std=gnu++17 -O1 -o "$work_dir/resid-voice-capture" \
    -I"$GENERATED_INCLUDE" -I"$RESID_SRC" \
    "$work_dir/main.cc" \
    "$RESID_SRC/sid.cc" \
    "$RESID_SRC/voice.cc" \
    "$RESID_SRC/wave.cc" \
    "$RESID_SRC/envelope.cc" \
    "$RESID_SRC/$filter_src" \
    "$RESID_SRC/dac.cc" \
    "$RESID_SRC/extfilt.cc" \
    "$RESID_SRC/pot.cc"
    # version.cc is omitted: it wants VICE's config.h VERSION and the tap does
    # not touch it.

"$work_dir/resid-voice-capture"
