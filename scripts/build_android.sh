#!/usr/bin/env bash
# ==========================================================
# aPS3e — build the APK (authoritative recipe)
# ==========================================================
# This is THE build recipe: one file, run identically by the etk-cloud lane and
# by any other box that has the toolchain. It exists because for most of this
# project's life the recipe lived only in an operator's SSD sparseimage and a
# memory file — the exact "recipe reachable from nowhere" failure the fleet
# audit found in four other lanes (TRACK_MANUAL §8.5).
#
# Runs on the HOST and drives the provisioned container, so the ccache and the
# Gradle dependency cache stay warm between builds (a cold LLVM build is hours).
#
#   ./build_android.sh                          # release, in aps3e-ndk
#   ./build_android.sh --debug
#   ./build_android.sh --marker "pad-movie v2.2"  # recompile-proof gate
#   ./build_android.sh --expect-cert <sha256>     # signing-identity gate
#   ./build_android.sh --require-clean            # refuse to build a dirty tree
#   ./build_android.sh --native                   # no container (host toolchain)
#
# Prerequisite: scripts/provision_android_toolchain.sh has run green.
# ==========================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

CONTAINER="${APS3E_CONTAINER:-aps3e-ndk}"
LANE_ROOT="${APS3E_LANE_ROOT:-$HOME/aps3e-lane}"
BUILD_TYPE=release
MARKER=""
EXPECT_CERT=""
NATIVE=0
REQUIRE_CLEAN=0
# The Air's 8 GB forced LINK_JOBS=1; a 23 GB node does not need that brake.
LLVM_COMPILE_JOBS="${APS3E_LLVM_COMPILE_JOBS:-4}"
LLVM_LINK_JOBS="${APS3E_LLVM_LINK_JOBS:-2}"

while [ $# -gt 0 ]; do
    case "$1" in
        --debug)   BUILD_TYPE=debug; shift ;;
        --release) BUILD_TYPE=release; shift ;;
        --marker)  MARKER="${2:?--marker needs a value}"; shift 2 ;;
        --expect-cert) EXPECT_CERT="${2:?--expect-cert needs a value}"; shift 2 ;;
        --native)  NATIVE=1; shift ;;
        --require-clean) REQUIRE_CLEAN=1; shift ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

log()  { printf '[build_android] %s\n' "$*"; }
fail() { printf '[build_android] FATAL: %s\n' "$*" >&2; exit 1; }

# In-container paths. The repo is bind-mounted with the lane root, so the
# container sees this checkout at /work/src.
if [ "$NATIVE" = 1 ]; then
    RUN() { bash -lc "$1"; }
    SRC="$REPO"
    OUT="$LANE_ROOT/out"
else
    docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" \
        || fail "container $CONTAINER is not running — run scripts/provision_android_toolchain.sh"
    RUN() { docker exec "$CONTAINER" bash -lc "$1"; }
    SRC=/work/src
    OUT=/work/out
fi

GRADLE_TASK="assemble$(printf '%s' "${BUILD_TYPE:0:1}" | tr '[:lower:]' '[:upper:]')${BUILD_TYPE:1}"
APK_PATH="app/build/outputs/apk/$BUILD_TYPE/app-$BUILD_TYPE.apk"

# ==========================================================
# BUILD
# ==========================================================
log "build type: $BUILD_TYPE   task: $GRADLE_TASK"
log "llvm jobs: compile=$LLVM_COMPILE_JOBS link=$LLVM_LINK_JOBS"

RUN "set -euo pipefail
     [ -f /work/toolchain-env.sh ] && . /work/toolchain-env.sh
     cd '$SRC'

     # local.properties is gitignored and per-box; regenerate it every run so a
     # moved SDK can never leave a stale path behind.
     printf 'sdk.dir=%s\n' \"\$ANDROID_HOME\" > local.properties

     # The signing identity has to be the previous builder's debug keystore or
     # 'adb install -r' is rejected on a device that already has aPS3e.
     mkdir -p ~/.android
     if [ -f /work/keystore/debug.keystore ]; then
         cp -f /work/keystore/debug.keystore ~/.android/debug.keystore
     fi

     ccache -M 20G >/dev/null 2>&1 || true
     ./gradlew --no-daemon --stacktrace \
        -Pandroid.aapt2FromMavenOverride=\"\$APS3E_AAPT2\" \
        -PetkCcache=1 \
        -PetkLlvmCompileJobs=$LLVM_COMPILE_JOBS \
        -PetkLlvmLinkJobs=$LLVM_LINK_JOBS \
        $GRADLE_TASK"

# ==========================================================
# GATES — the trap each one catches is named. Style: lane_turnip.sh.
# ==========================================================
log "gates:"

# 1. APK present and not a stub.
SZ=$(RUN "stat -c %s '$SRC/$APK_PATH' 2>/dev/null || echo 0" | tr -dc '0-9')
[ "${SZ:-0}" -gt 20000000 ] || fail "APK missing or implausibly small (${SZ:-0} B) at $APK_PATH"
log "  apk               $SZ B"

# 2. The native library must be there and must be arm64. A toolchain that
#    silently fell back to the host arch would still produce an APK.
RUN "set -e
     cd '$SRC'
     rm -rf /tmp/apkchk && mkdir -p /tmp/apkchk
     unzip -o -q '$APK_PATH' 'lib/arm64-v8a/libe.so' -d /tmp/apkchk"
MACH=$(RUN "readelf -h /tmp/apkchk/lib/arm64-v8a/libe.so | awk -F: '/Machine/{print \$2}' | xargs")
case "$MACH" in
    *AArch64*) log "  libe.so machine   $MACH" ;;
    *) fail "libe.so is not AArch64 (got '$MACH')" ;;
esac

# 3. Identity of the native blob. build-id moving between runs is the cheap
#    proof that the native side actually recompiled rather than being served
#    from a stale cache — the hand-check this lane replaces.
LIBSZ=$(RUN "stat -c %s /tmp/apkchk/lib/arm64-v8a/libe.so")
LIBSHA=$(RUN "sha256sum /tmp/apkchk/lib/arm64-v8a/libe.so | cut -d' ' -f1")
BUILDID=$(RUN "readelf -n /tmp/apkchk/lib/arm64-v8a/libe.so | awk '/Build ID/{print \$3}'" || true)
log "  libe.so           $LIBSZ B  build-id=${BUILDID:-none}"
log "  libe.so sha256    $LIBSHA"

# 4. Optional recompile proof against a string from the change under test.
if [ -n "$MARKER" ]; then
    if RUN "strings /tmp/apkchk/lib/arm64-v8a/libe.so | grep -qF '$MARKER'"; then
        log "  marker            present: '$MARKER'"
    else
        fail "marker '$MARKER' NOT in libe.so — the native side did not rebuild your change"
    fi
fi

# 5. Signing identity. A box that minted its own debug keystore produces an APK
#    the rig will refuse to install over the existing one.
CERT=$(RUN "as=\$(ls -d \$ANDROID_HOME/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)
            [ -n \"\$as\" ] && \"\$as\" verify --print-certs '$SRC/$APK_PATH' 2>/dev/null \
            | awk -F': ' '/SHA-256 digest/{print \$2; exit}'" || true)
if [ -n "$CERT" ]; then
    log "  signing cert      $CERT"
    if [ -n "$EXPECT_CERT" ] && [ "$CERT" != "$EXPECT_CERT" ]; then
        fail "signing cert mismatch — this APK will NOT install over the rig's existing aPS3e.
       got      $CERT
       expected $EXPECT_CERT
       (stage the previous builder's ~/.android/debug.keystore into $LANE_ROOT/keystore/)"
    fi
else
    log "  signing cert      UNVERIFIED (apksigner did not report one)"
fi

# ==========================================================
# STAGE
# ==========================================================
VERNAME=$(RUN "grep -m1 'versionName' '$SRC/app/build.gradle' | sed 's/.*\"\\(.*\\)\".*/\\1/'" || echo unknown)
COMMIT=$(RUN "git -C '$SRC' rev-parse --short=9 HEAD" 2>/dev/null || echo unknown)

# Provenance: a commit id on an artifact built from a MODIFIED tree is a lie,
# and it is the lie that is hardest to catch later. app/build.gradle is the
# usual culprit — it is a real tracked file now, but any hand-edit or streamed
# patch on the node leaves HEAD pointing somewhere the artifact did not come
# from. Same law as the Turnip lane's embedded-git-sha check.
# git must be INTERROGABLE before its answers mean anything. The container runs
# as root against a repo owned by the host user, so git refuses it with
# "detected dubious ownership" unless it is marked safe — and when git fails,
# `status --porcelain | wc -l` prints 0, which reads exactly like a clean tree.
# That made --require-clean pass without checking anything on the first green
# build. A provenance gate that fails open is worse than no gate: treat an
# unreadable repo as fatal, never as clean.
RUN "git config --global --add safe.directory '$SRC' 2>/dev/null || true" >/dev/null 2>&1 || true
if [ "$COMMIT" = "unknown" ] || [ -z "$COMMIT" ]; then
    COMMIT=$(RUN "git -C '$SRC' rev-parse --short=9 HEAD 2>/dev/null" | tr -dc '0-9a-f' || true)
fi
[ -n "$COMMIT" ] || fail "cannot read git HEAD in $SRC — provenance is unverifiable.
       Refusing to stamp an artifact with a commit id nobody can check."

DIRTY=$(RUN "git -C '$SRC' status --porcelain 2>/dev/null | wc -l; echo rc=\$?" || true)
case "$DIRTY" in
    *rc=0*) DIRTY=$(printf '%s' "$DIRTY" | head -1 | tr -dc '0-9') ;;
    *) fail "git status failed in $SRC — cannot tell a clean tree from an unreadable one" ;;
esac
DIRTY="${DIRTY:-0}"
if [ "$DIRTY" -gt 0 ]; then
    if [ "$REQUIRE_CLEAN" = 1 ]; then
        fail "tree has $DIRTY modified/untracked path(s) — refusing to stamp an artifact
       with commit $COMMIT that it was not built from. Commit and push, or drop
       --require-clean to build a marked +dirty candidate."
    fi
    log "  WARNING           tree is DIRTY ($DIRTY paths) — artifact marked +dirty"
    log "                    commit $COMMIT does NOT describe what was built"
    COMMIT="${COMMIT}+dirty"
fi

ANAME="aps3e-${VERNAME}-${BUILD_TYPE}-${COMMIT}.apk"

RUN "mkdir -p '$OUT'
     cp -f '$SRC/$APK_PATH' '$OUT/$ANAME'
     cd '$OUT' && sha256sum '$ANAME' > '$ANAME.sha256'
     {
       echo \"artifact:   $ANAME\"
       echo \"size:       $SZ\"
       echo \"commit:     $COMMIT\"
       echo \"tree:       \$([ '$DIRTY' -eq 0 ] && echo clean || echo '$DIRTY paths modified — NOT reproducible from that commit')\"
       echo \"versionName:$VERNAME\"
       echo \"libe.so:    $LIBSZ B sha256=$LIBSHA build-id=${BUILDID:-none}\"
       echo \"signer:     ${CERT:-unverified}\"
       echo \"ndk:        \${APS3E_NDK_REV:-unknown} (aarch64 host)\"
     } > '$ANAME.buildinfo'"

ASHA=$(RUN "cut -d' ' -f1 '$OUT/$ANAME.sha256'")
log "artifact: $ANAME ${SZ} B sha256=$ASHA"
log "LANE OK"
