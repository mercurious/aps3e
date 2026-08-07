#!/usr/bin/env bash
# ==========================================================
# aPS3e — provision the Android build toolchain on a Linux aarch64 host
# ==========================================================
# THE PROBLEM THIS SOLVES: Google ships NDK host toolchains for linux-x86_64,
# darwin-x86_64 and windows-x86_64 only. There is no official aarch64 Linux
# NDK, so a native ARM build box (etk-cloud: Oracle A1, Ubuntu 24.04 aarch64)
# cannot build this project out of the box. Three pieces have to be supplied
# by hand, and each one is pinned by sha256 here:
#
#   1. NDK        — HomuHomu833/android-ndk-custom r27d, aarch64-linux-gnu.
#                   Its make-ndk.sh renames the host tag to linux-aarch64,
#                   leaves a linux-x86_64 compatibility symlink, and rewrites
#                   the ANDROID_HOST_TAG block in the cmake toolchain files,
#                   so AGP and android.toolchain.cmake both resolve.
#   2. aapt2      — AGP pulls aapt2 from Google Maven with a `linux` classifier
#                   that is x86_64-only; on ARM it dies with "exec format
#                   error". Supplied from HomuHomu833/android-sdk-custom and
#                   passed to Gradle as -Pandroid.aapt2FromMavenOverride.
#   3. CMake      — app/build.gradle pins cmake 3.22.1 and the SDK has no
#                   aarch64 build of it. Kitware's own aarch64 tarball is used,
#                   with ninja dropped beside it (AGP looks for ninja there).
#
# The SDK lives on the HOST and is bind-mounted, never inside the container:
# TRACK_MANUAL §8.5's finding was that the Turnip recipe existed only inside a
# container, one `docker rm` from gone. Here `docker rm aps3e-ndk` costs a
# re-provision, not the toolchain.
#
# Usage:
#   ./provision_android_toolchain.sh                 # provision / repair
#   ./provision_android_toolchain.sh --verify        # gates only, no changes
#   ./provision_android_toolchain.sh --accept-licenses
#
# The Android SDK license must be accepted before sdkmanager will install
# anything. This script will NOT accept it for you unless you pass
# --accept-licenses (or set ANDROID_SDK_LICENSES_ACCEPTED=1) — accepting a
# license agreement is the operator's call, not the build script's.
# ==========================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# --- PINS ------------------------------------------------------------------
# Toolchain parity is not automatic — pin it. On 2026-08-05 the Air and
# etk-cloud held *different images behind the same ubuntu:24.04 tag*
# (786a8b55 vs 561618e2), which is why the base is pinned by digest and not
# by tag. Same law as the chiaki lane.
BASE_IMAGE="ubuntu@sha256:561618e2c15bf2397621dd04f96926663a3b5616c189cf7e38db7e82f5c538ea"

NDK_REV="27.3.13750724"           # r27d — must equal app/build.gradle ndkVersion
NDK_URL="https://github.com/HomuHomu833/android-ndk-custom/releases/download/r27/android-ndk-r27d-aarch64-linux-gnu.tar.xz"
NDK_SHA256="568e69a57a0dcec3d885df3a1d184fffbdbd8edfef4d598d1911f98cf3baecef"

SDKC_URL="https://github.com/HomuHomu833/android-sdk-custom/releases/download/35.0.2/android-sdk-aarch64-linux-musl.tar.xz"
SDKC_SHA256="460544cb43f7208276cd41b7b3ed0ccc72a33700378c0fd3f5c07405fae4f82e"

# Must be recent enough to parse Google's current repository XML (v4). Build
# 11076708 could not, and silently offered no build-tools newer than 35.0.1 —
# sdkmanager then aborts the WHOLE --install on the one unknown package, so
# android-35 did not land either. sha1 cross-checked against the sha1 Google
# publishes for this file in repository2-4.xml: 040d3996a65543d22ec4bf73e4c37aa37a8d4af4
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip"
CMDLINE_SHA256="4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"

CMAKE_VER="3.22.1"                # must equal app/build.gradle cmake version
CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-aarch64.tar.gz"
CMAKE_SHA256="601443375aa1a48a1a076bda7e3cca73af88400463e166fffc3e1da3ce03540b"   # Kitware's published sum

SDK_PLATFORM="platforms;android-35"        # compileSdk 35
# 35.0.0, not 35.0.2 — Google's 35.x line ends at 35.0.1, and 35.0.0 is AGP
# 8.8's own default, so nothing gets auto-downloaded mid-build. (The third-party
# aapt2 archive is *tagged* 35.0.2; that is its versioning, not Google's.)
SDK_BUILDTOOLS="build-tools;35.0.0"

CONTAINER="${APS3E_CONTAINER:-aps3e-ndk}"
LANE_ROOT="${APS3E_LANE_ROOT:-$HOME/aps3e-lane}"

APT_PKGS="openjdk-17-jdk-headless build-essential git curl unzip xz-utils zip \
ca-certificates ccache ninja-build python3 file binutils"

# --- CLI -------------------------------------------------------------------
VERIFY_ONLY=0
ACCEPT_LICENSES="${ANDROID_SDK_LICENSES_ACCEPTED:-0}"
while [ $# -gt 0 ]; do
    case "$1" in
        --verify) VERIFY_ONLY=1; shift ;;
        --accept-licenses) ACCEPT_LICENSES=1; shift ;;
        -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

log()  { printf '>> %s\n' "$*"; }
fail() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

dex() { docker exec "$CONTAINER" bash -lc "$1"; }

# ==========================================================
# PREFLIGHT
# ==========================================================
command -v docker >/dev/null 2>&1 || fail "docker not found"
HOST_ARCH="$(uname -m)"
[ "$HOST_ARCH" = "aarch64" ] || [ "$HOST_ARCH" = "arm64" ] \
    || fail "this lane targets an aarch64 host (got $HOST_ARCH). On x86_64 use the official NDK."

mkdir -p "$LANE_ROOT"/{dl,sdk,ccache,gradle,keystore,src,out}

# ==========================================================
# FETCH — every artifact sha256-pinned; a present file with a matching sum is
# reused, a mismatch is fatal rather than silently rebuilt from a bad payload.
# ==========================================================
fetch_pinned() {  # <url> <sha256> <dest>
    local url="$1" want="$2" dest="$3" got
    case "$want" in
        __PIN_*) fail "unpinned artifact: $(basename "$dest")
       Download it, run: sha256sum $dest
       and replace $want in $0 with the value. Nothing here runs on TOFU." ;;
    esac
    if [ -f "$dest" ]; then
        got="$(sha256sum "$dest" | cut -d' ' -f1)"
        if [ "$got" = "$want" ]; then log "have $(basename "$dest") (sha ok)"; return 0; fi
        fail "$(basename "$dest") sha256 mismatch: $got != $want (delete it to refetch)"
    fi
    log "fetching $(basename "$dest")"
    curl -fsSL -o "$dest.part" "$url" || fail "download failed: $url"
    got="$(sha256sum "$dest.part" | cut -d' ' -f1)"
    [ "$got" = "$want" ] || fail "$(basename "$dest") sha256 mismatch after download: $got != $want"
    mv "$dest.part" "$dest"
}

if [ "$VERIFY_ONLY" = 0 ]; then
    fetch_pinned "$NDK_URL"     "$NDK_SHA256"     "$LANE_ROOT/dl/ndk-r27d.tar.xz"
    fetch_pinned "$SDKC_URL"    "$SDKC_SHA256"    "$LANE_ROOT/dl/sdk-custom-35.0.2.tar.xz"
    fetch_pinned "$CMDLINE_URL" "$CMDLINE_SHA256" "$LANE_ROOT/dl/cmdline-tools-15859902.zip"
    fetch_pinned "$CMAKE_URL"   "$CMAKE_SHA256"   "$LANE_ROOT/dl/cmake-$CMAKE_VER.tar.gz"
fi

# ==========================================================
# CONTAINER — long-lived and named, mirroring turnip-rocknix /
# rocknix-gtk-kernel-sid. forge.sh's preflight gates on `docker ps -a` showing
# it **Up**, not on the image existing (handoff trap #1).
# ==========================================================
if [ "$VERIFY_ONLY" = 0 ]; then
    if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
        log "container $CONTAINER exists; starting it"
        docker start "$CONTAINER" >/dev/null
    else
        log "creating container $CONTAINER from $BASE_IMAGE"
        docker run -d --name "$CONTAINER" \
            -v "$LANE_ROOT:/work" \
            -e ANDROID_HOME=/work/sdk \
            -e ANDROID_SDK_ROOT=/work/sdk \
            -e GRADLE_USER_HOME=/work/gradle \
            -e CCACHE_DIR=/work/ccache \
            -e JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64 \
            -w /work \
            "$BASE_IMAGE" sleep infinity >/dev/null
    fi

    log "installing build dependencies (idempotent)"
    dex "export DEBIAN_FRONTEND=noninteractive
         apt-get update -qq
         apt-get install -y -qq --no-install-recommends $APT_PKGS >/dev/null"

    # ---- Android SDK (cmdline-tools is pure Java — arch-independent) ----
    # Stamped with the pinned build id: "sdkmanager exists" is NOT a sufficient
    # guard, because an OLD cmdline-tools is exactly the failure mode here and
    # a presence check would happily keep it forever.
    # Everything under /work/sdk is written from INSIDE the container: docker
    # exec runs as root, so anything it creates in the bind mount is root-owned
    # and a host-side write into the same tree fails with EACCES.
    CMDLINE_STAMP="$LANE_ROOT/sdk/cmdline-tools/.build-id"
    if [ "$(cat "$CMDLINE_STAMP" 2>/dev/null || true)" != "$CMDLINE_SHA256" ]; then
        log "installing cmdline-tools (build 15859902)"
        dex "rm -rf /tmp/cmdt && mkdir -p /tmp/cmdt /work/sdk/cmdline-tools
             unzip -q /work/dl/cmdline-tools-15859902.zip -d /tmp/cmdt
             rm -rf /work/sdk/cmdline-tools/latest
             mv /tmp/cmdt/cmdline-tools /work/sdk/cmdline-tools/latest
             printf '%s\n' '$CMDLINE_SHA256' > /work/sdk/cmdline-tools/.build-id"
    fi

    # ---- NDK r27d aarch64 ----
    if [ ! -f "$LANE_ROOT/sdk/ndk/$NDK_REV/source.properties" ]; then
        log "installing NDK $NDK_REV (aarch64 host)"
        dex "rm -rf /tmp/ndk && mkdir -p /tmp/ndk /work/sdk/ndk
             tar -xf /work/dl/ndk-r27d.tar.xz -C /tmp/ndk
             src=\$(find /tmp/ndk -maxdepth 2 -name source.properties | head -1)
             [ -n \"\$src\" ] || { echo 'no source.properties in the NDK tarball'; exit 1; }
             rm -rf /work/sdk/ndk/$NDK_REV
             mv \"\$(dirname \"\$src\")\" /work/sdk/ndk/$NDK_REV"
    fi

    # ---- CMake 3.22.1 aarch64 (+ ninja beside it, where AGP looks) ----
    if [ ! -x "$LANE_ROOT/sdk/cmake/$CMAKE_VER/bin/cmake" ]; then
        log "installing CMake $CMAKE_VER (aarch64) + ninja"
        dex "rm -rf /tmp/cm && mkdir -p /tmp/cm /work/sdk/cmake
             tar -xf /work/dl/cmake-$CMAKE_VER.tar.gz -C /tmp/cm --strip-components=1
             rm -rf /work/sdk/cmake/$CMAKE_VER
             mv /tmp/cm /work/sdk/cmake/$CMAKE_VER
             ln -sf \$(command -v ninja) /work/sdk/cmake/$CMAKE_VER/bin/ninja"
    fi

    # ---- aarch64 aapt2 ----
    # The archive is tagged 35.0.2 but its internal build-tools dir is 35.0.0;
    # only aapt2 is taken from it, so that skew does not reach the build. It is
    # a statically linked aarch64 ELF (verified), which is why it drops in
    # cleanly next to a glibc SDK.
    if [ ! -x "$LANE_ROOT/sdk/aapt2-aarch64/aapt2" ]; then
        log "installing aarch64 aapt2"
        dex "rm -rf /tmp/sdkc && mkdir -p /tmp/sdkc /work/sdk/aapt2-aarch64
             tar -xf /work/dl/sdk-custom-35.0.2.tar.xz -C /tmp/sdkc
             a2=\$(find /tmp/sdkc -type f -name aapt2 | head -1)
             [ -n \"\$a2\" ] || { echo 'no aapt2 in the custom SDK archive'; exit 1; }
             cp \"\$a2\" /work/sdk/aapt2-aarch64/aapt2
             chmod 0755 /work/sdk/aapt2-aarch64/aapt2"
    fi

    # ---- SDK components (LAST — the only license-gated step) ----
    # Deliberately last so an operator who has not accepted the SDK licence
    # still gets the NDK, CMake and aapt2 installed and gated. Only the
    # Google-hosted platform/build-tools packages need the agreement.
    if [ ! -d "$LANE_ROOT/sdk/platforms/android-35" ]; then
        if [ "$ACCEPT_LICENSES" != "1" ]; then
            fail "the Android SDK licence has not been accepted.
       Everything else is installed; sdkmanager will fetch nothing until it is.
       Re-run with:
           $0 --accept-licenses
       (that is the operator's decision to make, not this script's)"
        fi
        log "accepting Android SDK licences (operator-authorised via --accept-licenses)"
        dex "yes | /work/sdk/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null 2>&1 || true"
        log "installing $SDK_PLATFORM $SDK_BUILDTOOLS platform-tools"
        dex "/work/sdk/cmdline-tools/latest/bin/sdkmanager --install \
             '$SDK_PLATFORM' '$SDK_BUILDTOOLS' 'platform-tools' >/dev/null"
    fi

    # ---- derived env, sourced by build_android.sh ----
    cat > "$LANE_ROOT/toolchain-env.sh" <<EOF
# generated by provision_android_toolchain.sh — do not edit by hand
export ANDROID_HOME=/work/sdk
export ANDROID_SDK_ROOT=/work/sdk
export GRADLE_USER_HOME=/work/gradle
export CCACHE_DIR=/work/ccache
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
export APS3E_NDK_REV=$NDK_REV
export APS3E_AAPT2=/work/sdk/aapt2-aarch64/aapt2
export PATH=/work/sdk/cmake/$CMAKE_VER/bin:/work/sdk/platform-tools:\$PATH
EOF
fi

# ==========================================================
# GATES — verify the toolchain, never assume it. Each of these has a real
# failure mode behind it; the aapt2 one is the most likely to be a silently
# wrong x86_64 binary sitting under a correct-looking filename.
# ==========================================================
NDK_TC="/work/sdk/ndk/$NDK_REV/toolchains/llvm/prebuilt"
# The host tag is DETECTED, not assumed. This build names it linux-arm64 (not
# linux-aarch64) and ships a linux-x86_64 -> linux-arm64 compat symlink; the
# NDK's own android.toolchain.cmake computes "linux-${ARCH}" at configure time,
# so the real directory is whatever that build chose. Hardcoding it here would
# make the gate fail on a correct toolchain.
NDK_HOST_TAG=$(docker exec "$CONTAINER" bash -lc \
    "find $NDK_TC -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | head -1" || true)
NDK_HOST_TAG="${NDK_HOST_TAG:-linux-arm64}"

log "gates:"
GATE_FAIL=0
gate() {  # <label> <shell-command-in-container>
    local label="$1"; shift
    local out
    if out=$(dex "$1" 2>&1); then
        printf '     %-22s %s\n' "$label" "$(printf '%s' "$out" | head -1)"
    else
        printf '     %-22s FAIL: %s\n' "$label" "$(printf '%s' "$out" | head -1)"
        GATE_FAIL=1
    fi
}

gate "ndk revision" \
     "grep '^Pkg.Revision' /work/sdk/ndk/$NDK_REV/source.properties | tr -d ' '"
gate "ndk host tag" \
     "test -d $NDK_TC/$NDK_HOST_TAG && test -e $NDK_TC/linux-x86_64 && echo '$NDK_HOST_TAG (+ linux-x86_64 compat symlink)'"
gate "clang is native" \
     "file -bL $NDK_TC/$NDK_HOST_TAG/bin/clang | cut -c1-52"
gate "clang runs" \
     "$NDK_TC/$NDK_HOST_TAG/bin/clang --version | head -1"
gate "clang via compat tag" \
     "$NDK_TC/linux-x86_64/bin/clang --version | head -1"
gate "linker + archiver" \
     "cd $NDK_TC/$NDK_HOST_TAG/bin && ls ld.lld llvm-ar llvm-strip clang++ | tr '\n' ' '"
gate "aapt2 runs" \
     "/work/sdk/aapt2-aarch64/aapt2 version"
gate "cmake" \
     "/work/sdk/cmake/$CMAKE_VER/bin/cmake --version | head -1"
gate "ninja beside cmake" \
     "/work/sdk/cmake/$CMAKE_VER/bin/ninja --version"
gate "java" \
     "java -version 2>&1 | head -1"
gate "host c++ (llvm tblgen)" \
     "g++ --version | head -1"
gate "platform android-35" \
     "test -d /work/sdk/platforms/android-35 && echo present"

# The signing identity gate. The release buildType signs with
# signingConfigs.debug, i.e. ~/.android/debug.keystore. A box that mints its
# own gets a DIFFERENT cert, and `adb install -r` over the rig's existing
# install then fails INSTALL_FAILED_UPDATE_INCOMPATIBLE. Never generate one
# here — it must be the same keystore the previous builder used.
if [ -f "$LANE_ROOT/keystore/debug.keystore" ]; then
    printf '     %-22s %s\n' "debug keystore" "present (staged from the previous builder)"
else
    printf '     %-22s %s\n' "debug keystore" "MISSING"
    echo
    echo "  The release APK signs with the default debug keystore. Copy the one the"
    echo "  previous builder used, or every APK from this box will be rejected by"
    echo "  'adb install -r' on a device that already has aPS3e installed:"
    echo
    echo "      scp ~/.android/debug.keystore <this-host>:$LANE_ROOT/keystore/"
    echo
    GATE_FAIL=1
fi

echo
if [ "$GATE_FAIL" != 0 ]; then
    fail "toolchain gates FAILED (see above)"
fi
log "toolchain OK — build with: scripts/build_android.sh"
