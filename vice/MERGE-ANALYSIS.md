# VICE core convergence — empirical merge analysis (WAL-119, Phase A)

Validates ADR 0004's central claim ("the two forks' deltas against upstream are
orthogonal → a single 3.10.0 tree hosts both with zero merge conflict") against
the **actual** source trees, using pristine upstream **VICE 3.10** (SourceForge
release tarball) as the 3-way merge base.

## Method

- `base`   = upstream `vice-3.10` (release tarball; no `src/mcp`, no `src/arch/macos`)
- `ours`   = `barryw/vice-macos` `vice/` tree
- `theirs` = `barryw/vice-mcp` `vice/` tree
- Per shared file: classify vs base, then `git merge-file` 3-way to detect real conflicts.

## Results

Diff of the two forks' `vice/` trees: **139** paths only-in-mcp, **24** only-in-macos,
**44** shared files differing.

Of the 139 "only-in-mcp": **1** is the real `src/mcp/` module; the other 138 are
checked-in autotools artifacts (`configure`, `*/Makefile.in`, `aclocal.m4`,
`compile`, generated `novte`/`gtk3` files). vice-macos is **source-only** and
regenerates these — so the canonical tree follows the source-only convention.

Classifying the 44 shared differing files vs the upstream base:

| Class | Count | Handling |
|---|---:|---|
| macOS-only edit (mcp == upstream) | 24 | keep foundation (macOS) |
| mcp-only edit (macOS == upstream) | 3 | take mcp: `src/init.c`, `src/maincpu.h`, `src/vice.h` |
| edited by **both** forks | 14 | 3-way merge |
| not in release tarball (vendored libresidfp) | 3 | keep macOS; reconcile later ⚠ |

3-way merge of the 14 both-edited files → **only 2 produce conflicts**:

1. **`configure.ac` — 1 hunk, cosmetic.** Both forks reorder the libresidfp `-I`
   include flags (`-I$(top_srcdir)/… -I$(top_builddir)/…` vs the reverse).
   Functionally identical. Auto-resolved in favour of the macOS foundation.
   *All other configure.ac deltas (the `--enable-mcp-server` block, libmicrohttpd
   check, the `--enable-macosui` block) merge cleanly in non-conflicting hunks.*

2. **`src/monitor/mon_parse.c` — 127 hunks, generated.** This is bison output.
   The grammar source `src/monitor/mon_parse.y` is **byte-identical** across both
   forks, so the conflicts are pure regeneration noise (different bison versions).
   Resolution: keep the foundation copy and let CI regenerate via
   `bison -d -o src/monitor/mon_parse.c src/monitor/mon_parse.y` (already done by
   both forks' pipelines). No hand-merge of generated code.

**Conclusion:** ADR 0004's premise holds. The entire *functional* merge surface
reduces to **one cosmetic `configure.ac` line**. mcp's monitor integration lives
in `monitor.c`/`monitor.h` (which 3-way merge clean), not in the grammar. Core
emulation paths (VIC-II/SID/CPU) are untouched by the mcp delta. Risk is CI
plumbing, not core breakage — exactly as ADR 0004 predicted.

## Open item — vendored libresidfp divergence ⚠

`src/lib/libresidfp/src/SID.h` (51 lines), `src/lib/libresidfp/src/Voice.h`
(7 lines) and `src/sid/residfp.cc` (115 lines) differ between the two forks and
are **absent from the 3.10 release tarball** (libresidfp is an `AX_SUBDIRS_CONFIGURE`
subproject vendored at a different snapshot). One fork carries a newer/patched
libresidfp. This is a **reconciliation decision** (pick the newer, or a common
snapshot), not a blocker — the canonical tree currently keeps the macOS copy.
Tracked as a follow-up child of WAL-119.
