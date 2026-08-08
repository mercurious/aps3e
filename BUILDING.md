# Building the aPS3e ETK fork

Builds happen on **etk-cloud** (Oracle Ampere A1, 4 cores / 23 GB / Ubuntu
24.04 aarch64, native docker). The MacBook Air is the stager and the only box
that touches the rig over adb — it is no longer a builder.

---

## Quick start

Toolchain already provisioned (container `aps3e-ndk`):

```bash
ssh etk-cloud 'cd ~/aps3e-lane && ./src/scripts/build_android.sh \
    --require-clean \
    --expect-cert 6578ae5937ae33c4ac8eb5178e0d7ef5bad69b542d14425c0b25342961c181dc \
    --marker GTK_REMAP0_ONE,GTK_REMAP0_IDENTITY'
```

A full cold build is ~1 h (measured 1 h 05 m while sharing the node with a
kernel build). A warm incremental rebuild is ~40 s. Long builds should run
detached with an rc marker so a dropped ssh cannot kill them:

```bash
ssh etk-cloud 'cd ~/aps3e-lane && setsid nohup bash -c "
  ./src/scripts/build_android.sh --require-clean ... ; echo \$? > build.rc
" >> build.log 2>&1 < /dev/null &'
```

Then pull the artifact to the Air and verify the sha survived the transfer:

```bash
ssh etk-cloud 'cat ~/aps3e-lane/out/<name>.apk' > artifacts/<name>.apk
shasum -a 256 artifacts/<name>.apk   # must equal the node's .sha256
adb install -r artifacts/<name>.apk  # Flip2 1bb6a94, package aenu.aps3e
```

## Provisioning a fresh host

```bash
./scripts/provision_android_toolchain.sh --accept-licenses
```

Idempotent; safe to re-run. It refuses to accept Google's SDK licence without
the explicit flag. It will also refuse to proceed if
`~/aps3e-lane/keystore/debug.keystore` is missing — see *Signing* below.

---

## Why this is not a normal Android build

**Google ships no aarch64 Linux NDK.** Host tags are `linux-x86_64`,
`darwin-x86_64` and `windows-x86_64` only. (The darwin package is a fat binary
with native arm64 slices, so Apple Silicon was never emulating — the move to
the cloud was for RAM and unattended runtime, not to escape Rosetta.) Three
pieces therefore come from outside the SDK, each sha256-pinned in the
provisioning script:

| piece | source | why |
|---|---|---|
| NDK **r27d** (27.3.13750724) | `HomuHomu833/android-ndk-custom`, `aarch64-linux-gnu` | the only native aarch64 host toolchain |
| aarch64 **aapt2** | `HomuHomu833/android-sdk-custom` | AGP's Maven aapt2 is x86_64 only → `exec format error` |
| **CMake 3.22.1** aarch64 | Kitware | `app/build.gradle` pins 3.22.1; the SDK has no aarch64 build |

Consequences worth knowing:

- `ndkVersion` is **27.3.13750724**, not r27 stable — the aarch64 prebuilts
  start at r27d. AGP fails configure rather than substituting a near miss.
- The NDK host tag directory is **`linux-arm64`**, not `linux-aarch64`, with a
  `linux-x86_64` compatibility symlink. Detect it, never hardcode it.
- It is a **custom LLVM build**, so codegen is not Google's. Binaries from this
  lane are not bit-comparable with any produced by an official NDK. Same class
  of caveat as the Turnip lane. This is only safe because there is now exactly
  one builder — do not reintroduce a second.
- The base image is pinned **by digest**, not by tag: the Air and etk-cloud
  once held different images behind an identical `ubuntu:24.04` tag.

The SDK lives on the host at `~/aps3e-lane/sdk`, bind-mounted into the
container, so `docker rm aps3e-ndk` costs a re-provision and not the toolchain.

## Signing

Release signs with `signingConfigs.debug`, i.e. the default debug keystore. A
host that mints its own gets a different certificate, and `adb install -r` is
then **rejected** on a device that already has aPS3e. The keystore is staged at
`~/aps3e-lane/keystore/debug.keystore`; its certificate SHA-256 is

```
6578ae5937ae33c4ac8eb5178e0d7ef5bad69b542d14425c0b25342961c181dc
```

Always pass it as `--expect-cert` so a wrong-identity build fails at the gate
instead of on the rig.

## Gates

`build_android.sh` fails loud on each of these:

1. APK present and > 20 MB
2. `lib/arm64-v8a/libe.so` present and reports **AArch64**
3. `libe.so` size / sha256 / GNU build-id recorded (a build-id that did not move
   across a change means the native side did not rebuild)
4. `--marker A,B,C` — every listed string must appear in the **extracted**
   `libe.so`. Note `strings` on the APK itself proves nothing: `libe.so` is a
   compressed zip entry, so the check must extract first.
5. `--expect-cert` — signing identity
6. `--require-clean` — refuses to stamp a commit id onto an artifact built from
   a modified tree. Git must be *interrogable*: an unreadable repo is fatal, not
   "clean" (`git status --porcelain | wc -l` prints 0 when git fails, which once
   let this gate pass having verified nothing).

## Choosing what to build — read this before you build

ETK work lives across several branches, frequently as the same change under
different SHAs, and there is **no canonical integration branch**. A build off
the wrong tip passes every gate above and is still wrong. Verify by patch-id:

```bash
for b in etk-tune shader-cache-manager fix-overlay-icons pr-18844-backport; do
    echo "== $b"; git cherry HEAD "origin/$b" | grep '^+' || echo "   (nothing missing)"
done
```

On 2026-08-07 a build off the `pad-movie` tip shipped without the #11912
road-flicker fix, which sat one commit away on `etk-tune`. Every gate was green.
The operator found it by reproducing the bug at the Daytona starting line.

`--marker` guards native patches only; Java-side changes leave no string in
`libe.so` and will pass regardless.

---

## RETIRED: the macOS local toolchain

`/Volumes/Extreme SSD/aps3e-build.sparseimage` (mounts at
`/Volumes/aps3e-build/aps3e`) is **retired as of 2026-08-07**. Do not build
there.

It is a plain non-git tree that worked only because `app/build.gradle` and a
vendored `abseil-cpp` had been hand-copied into it — neither was in version
control, so its output corresponds to no commit anywhere. Using it also puts a
second compiler back in the fleet, which is the precise A/B contamination the
move to etk-cloud eliminated: two arms of one experiment, two compilers, no way
to tell them apart in the ledger afterwards.

Both of those gaps are now fixed in git, so any clean checkout builds. The
sparseimage has no remaining advantage and one large hazard.

---

## Pathway: a `forge.sh aps3e` lane (documented, deliberately not built)

Not implemented — aPS3e is marked for retirement and the standalone script
already covers the capability. `forge.sh` would add sequencing convenience, not
capability. If it is ever wanted, the shape is settled:

- `tools/forge/lane_aps3e.sh` in the etk repo, modelled on `lane_turnip.sh`:
  runs on the node, delegates to this repo's `scripts/build_android.sh`, and
  re-asserts gates 1–5 with the trap named in each failure message.
- `FORGE_APS3E_*` knobs in `forge.sh`'s knob block plus `etk.conf.example`; add
  `aps3e` to the arg parser, `SEL_LANES` default and `TUI_STEP_LABELS`.
- Preflight: `need_container aps3e-ndk aps3e` — gate on `docker ps -a` showing
  it **Up**, not on the image existing.
- `fp_compute`: fork HEAD + NDK tarball sha + `app/build.gradle` sha.
- Stage to this repo's `artifacts/`, **not** `etk/emulators/` — the APK is not
  an ETK release asset and must stay outside `release_sanity.sh`'s gate.
- Caveat: forge's 1200 s stall warning fires spuriously when another lane has
  the box. The rc marker stays authoritative; do not tune the threshold against
  a moving target.
