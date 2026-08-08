# aPS3e (ETK fork) — agent notes

## Build this on etk-cloud. Not on the Mac.

```bash
ssh etk-cloud 'cd ~/aps3e-lane && ./src/scripts/build_android.sh \
    --require-clean \
    --expect-cert 6578ae5937ae33c4ac8eb5178e0d7ef5bad69b542d14425c0b25342961c181dc \
    --marker GTK_REMAP0_ONE,GTK_REMAP0_IDENTITY'
```

Full detail: [BUILDING.md](BUILDING.md). Toolchain setup:
`scripts/provision_android_toolchain.sh`.

## RETIRED — do not use, do not resurrect

There is an old local toolchain on a macOS external drive:
`/Volumes/Extreme SSD/aps3e-build.sparseimage` → `/Volumes/aps3e-build/aps3e`.
It is a **plain non-git tree**. It is retired as of 2026-08-07 and must not be
used to produce an APK.

It will look like a convenient warm build cache. It is not. It built only
because `app/build.gradle` and a vendored `abseil-cpp` had been copied into it
by hand, off version control — so it can silently produce a binary that
corresponds to no commit anywhere. Building there also puts a **second
compiler** in the fleet (Apple clang via NDK darwin prebuilts vs the cloud's
aarch64 clang 18), which reintroduces exactly the A/B contamination the move to
etk-cloud was made to remove: two arms of one experiment built by two
compilers, indistinguishable in the ledger.

If a build must happen off etk-cloud, run `scripts/build_android.sh` against a
clean checkout of this repo — never that sparseimage — and mark the resulting
artifact as off-fleet.

## Two traps this repo has already sprung

**1. Build from the ETK-tuned tip, not whatever branch is checked out.** ETK
work is spread across several branches (`etk-tune`, `shader-cache-manager`,
`fix-overlay-icons`, `pr-18844-backport`, `pad-movie`), often as the same
change under different SHAs. On 2026-08-07 a build off the `pad-movie` tip
shipped without the #11912 road-flicker fix — every gate passed, and only the
operator reproducing the bug on the rig caught it. Before building:

```bash
for b in etk-tune shader-cache-manager fix-overlay-icons pr-18844-backport; do
    echo "== $b"; git cherry HEAD "origin/$b" | grep '^+' || echo "   (nothing missing)"
done
```

`git cherry` matches by patch-id, so it sees through cherry-picks and rebases.
Anything printed with `+` is a patch your build will NOT contain.

**2. macOS and Windows are case-insensitive; Linux is not.** A reference whose
case does not match the file on disk resolves silently on the first two and is
fatal on the third. `Loader/iso.{cpp,h}` vs 14 `ISO.*` references cost a build
cycle here. When adding files, match the case of existing references exactly.

## Gotchas

- `app/build.gradle` is **tracked in this fork** (upstream gitignores it). It
  holds `ndkVersion`, the LLVM job throttles and the signing config; a clean
  clone cannot build without it. Keep it out of upstream PRs.
- Release signs with `signingConfigs.debug`. The APK must carry cert
  `6578ae59…c181dc` or `adb install -r` is rejected on a rig that already has
  aPS3e. Always pass `--expect-cert`.
- `--marker` only catches patches that leave a **native** string. Java-side
  changes (e.g. the MediaStore shader-cache fix) will pass it regardless — use
  `git cherry` for those.
