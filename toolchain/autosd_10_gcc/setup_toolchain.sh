# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
#!/bin/bash
set -euo pipefail

# Parse arguments
HOST_ARCH=""
TARGET_ARCH=""
SYSROOT_DIR=""
CROSS_MODE=false

usage() {
    cat >&2 <<EOF
Set up an AutoSD 10 GCC toolchain by downloading and extracting RPMs into a
directory. Builds a native toolchain, or a cross toolchain when --host and
--target differ.

Usage:
  $0 --target ARCH SYSROOT_DIR                  # native
  $0 --host ARCH --target ARCH SYSROOT_DIR      # cross

Options:
  --host ARCH     Architecture the tools run on. Defaults to --target (native).
  --target ARCH   Architecture the tools emit code for. Required.
  -h, --help      Show this help and exit.

Arguments:
  SYSROOT_DIR     Output directory. Required.
                  Native: usr/, lib64/, lib/ are placed directly inside it; must
                          not already contain an extracted toolchain (usr/ or
                          SYSROOT_INFO), so "." may be used as SYSROOT_DIR.
                  Cross:  host tools go in HOST_ARCH/ and the target sysroot in
                          TARGET_ARCH/, each in its own per-arch subdirectory
                          (pass SYSROOT_DIR/TARGET_ARCH to gcc --sysroot). Only
                          those two subdirectories must be empty/absent, so "."
                          may be used as SYSROOT_DIR.

Examples:
  $0 --target x86_64 sysroot-x86_64                   # native x86_64
  $0 --target aarch64 sysroot-aarch64                 # native aarch64
  $0 --host x86_64 --target aarch64 sysroot-crossland  # cross -> aarch64
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage; exit 0 ;;
        --host)
            [ $# -lt 2 ] && { echo "ERROR: --host requires an architecture" >&2; usage; exit 1; }
            HOST_ARCH="$2"; shift 2 ;;
        --target)
            [ $# -lt 2 ] && { echo "ERROR: --target requires an architecture" >&2; usage; exit 1; }
            TARGET_ARCH="$2"; shift 2 ;;
        -*)
            echo "ERROR: Unknown option: $1" >&2; usage; exit 1 ;;
        *)
            [ -n "$SYSROOT_DIR" ] && { echo "ERROR: Unexpected extra argument: $1" >&2; usage; exit 1; }
            SYSROOT_DIR="$1"; shift ;;
    esac
done

if [ -z "$TARGET_ARCH" ]; then
    echo "ERROR: --target is required" >&2; usage; exit 1
fi
if [ -z "$SYSROOT_DIR" ]; then
    echo "ERROR: missing SYSROOT_DIR (positional)" >&2; usage; exit 1
fi

# Default host to target => native build.
[ -z "$HOST_ARCH" ] && HOST_ARCH="$TARGET_ARCH"

if [ "$HOST_ARCH" = "$TARGET_ARCH" ]; then
    CROSS_MODE=false
    ARCH="$TARGET_ARCH"
else
    CROSS_MODE=true
    # download_package() keys off $ARCH; it is overridden per-batch below.
    ARCH="$HOST_ARCH"
fi

# Setup working directory: extract everything into SYSROOT_DIR.
WORK_DIR="$(pwd)"
mkdir -p "$SYSROOT_DIR"
# Native: refuse to extract on top of an already-extracted toolchain (stale
# trees would mix), while still allowing "." so the Bazel repo rule can extract
# in place alongside this script. Cross extracts into per-arch subdirs
# (HOST_ARCH/, TARGET_ARCH/) and validates those individually in run_cross_setup.
if [ "$CROSS_MODE" = false ] && { [ -e "$SYSROOT_DIR/usr" ] || [ -e "$SYSROOT_DIR/SYSROOT_INFO" ]; }; then
    echo "ERROR: $SYSROOT_DIR already contains an extracted toolchain; choose a fresh directory" >&2
    exit 1
fi
cd "$SYSROOT_DIR"

# Validate system requirements
validate_system_requirements() {
    local missing_tools=()

    for tool in rpm2cpio cpio bash grep sed find curl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "ERROR: Required tools are not available: ${missing_tools[*]}" >&2
        exit 1
    fi

    # Validate rpm2cpio works (accepts exit codes 0, 1, or 2)
    if ! rpm2cpio --help >/dev/null 2>&1; then
        set +e
        rpm2cpio >/dev/null 2>&1
        local exit_code=$?
        set -e
        if [ $exit_code -ne 0 ] && [ $exit_code -ne 1 ] && [ $exit_code -ne 2 ]; then
            echo "ERROR: rpm2cpio is not working properly" >&2
            exit 1
        fi
    fi
}

# Validate system before proceeding
validate_system_requirements

# AutoSD 10 repository URL
REPO_BASE_URL="https://autosd.sig.centos.org/AutoSD-10/nightly/repos/AutoSD/compose/AutoSD"
REPO_URL="${REPO_BASE_URL}/${ARCH}/os"

# AutoSD 10 packages to download for a native toolchain (versions discovered dynamically)
PACKAGES=(
    "gcc"
    "gcc-c++"
    "cpp"
    "binutils"
    "glibc-devel"
    "libstdc++-devel"
    "libstdc++"
    "kernel-headers"
    "glibc"
    "libgcc"
    "libmpc"
    "gmp"
    "mpfr"
    "jansson"
    "libatomic"
    "libtsan"
)

# Cross toolchain packages.
#  - CROSS_TOOL_PACKAGES / CROSS_HOST_SUPPORT_PACKAGES run on the host, pulled
#    from the host repo. The cross compiler ships crt*.o, libgcc and its builtin
#    headers but NO target C library. The support libraries are host runtime
#    deps of the cross tools: cc1/cc1plus need libmpc/libmpfr/libgmp and the
#    cross binutils (ld) needs libjansson (libz/libzstd/libm come from the host).
#  - CROSS_SYSROOT_PACKAGES provide the target C library / C++ runtime and
#    headers, pulled from the target repo into the ./TARGET_ARCH subtree.
CROSS_TOOL_PACKAGES=(
    "cross-binutils"
    "cross-gcc"
    "cross-gcc-c++"
)
CROSS_HOST_SUPPORT_PACKAGES=(
    "libmpc"
    "gmp"
    "mpfr"
    "jansson"
)
CROSS_SYSROOT_PACKAGES=(
    "glibc"
    "glibc-devel"
    "libstdc++"
    "libstdc++-devel"
    "libgcc"
    "kernel-headers"
    "libatomic"
    "libstdc++-static"
)

# Target directory for RPM extraction (relative to the repository root). The
# native toolchain extracts in place; the cross toolchain extracts the host
# tools into ./HOST_ARCH and the target sysroot into ./TARGET_ARCH so the two
# per-arch trees live in clearly named, separate directories and never mix.
EXTRACT_DIR="."

USER_AGENT="Multi-GCC-Toolchain/1.0"
MAX_RETRIES=3
MAX_VERSION_INCREMENTS=1  # Try up to 1 patch version increments

# Increment the patch version in an RPM filename
# Example: kernel-headers-6.12.0-157.el10.x86_64.rpm -> kernel-headers-6.12.0-158.el10.x86_64.rpm
increment_rpm_patch_version() {
    local rpm_file="$1"
    local increment="${2:-1}"

    # Match pattern: name-version-release.arch.rpm
    # Example: kernel-headers-6.12.0-157.el10.x86_64.rpm
    if [[ "$rpm_file" =~ ^(.+-)([0-9]+)(\.[^.]+\.[^.]+\.rpm)$ ]]; then
        local prefix="${BASH_REMATCH[1]}"
        local patch_version="${BASH_REMATCH[2]}"
        local suffix="${BASH_REMATCH[3]}"
        local new_patch=$((patch_version + increment))
        echo "${prefix}${new_patch}${suffix}"
    else
        echo "$rpm_file"
    fi
}

download_package() {
    local pkg_name="$1"
    local html_page="$2"

    local rpm_url
    local rpm_file
    local encoded_pkg_name="${pkg_name//+/%2B}"

    # Find package URL in AutoSD repository listing
    rpm_url=$(grep -o "href=\"[^\"]*/${encoded_pkg_name}-[0-9][^\"]*\\.${ARCH}\\.rpm\"" "$html_page" | \
        sed 's/href="//;s/"$//' | sort -V | tail -1)

    if [ -z "$rpm_url" ]; then
        rpm_url=$(grep -o "href=\"[^\"]*/${pkg_name}-[0-9][^\"]*\\.${ARCH}\\.rpm\"" "$html_page" | \
            sed 's/href="//;s/"$//' | sort -V | tail -1)
    fi

    if [ -z "$rpm_url" ]; then
        echo "[$pkg_name] ERROR: Package not found" >&2
        grep -i "${pkg_name}" "$html_page" | head -5 | sed "s/^/[$pkg_name]   /" >&2
        return 1
    fi

    rpm_file=$(basename "$rpm_url")
    rpm_file="${rpm_file//%2B/+}"

    echo "[$pkg_name] Downloading: $rpm_file" >&2

    local download_success=false
    local current_rpm_file="$rpm_file"
    local current_rpm_url="$rpm_url"
    local version_increment=0

    # Try downloading, with version increment fallback for 404 errors
    while [ $version_increment -le $MAX_VERSION_INCREMENTS ]; do
        if [ $version_increment -gt 0 ]; then
            current_rpm_file=$(increment_rpm_patch_version "$rpm_file" $version_increment)
            # Update URL with new filename
            current_rpm_url="${rpm_url%/*}/${current_rpm_file}"
            echo "[$pkg_name] Trying incremented version: $current_rpm_file" >&2
        fi

        # Attempt download with --fail to get proper exit codes for HTTP errors
        curl -L -A "$USER_AGENT" --max-time 180 --retry 2 --fail -# -o "$current_rpm_file" "$current_rpm_url" 2>&1 | sed "s/^/[$pkg_name] /" >&2
        local curl_exit_code=${PIPESTATUS[0]}

        if [ $curl_exit_code -eq 0 ]; then
            download_success=true
            rpm_file="$current_rpm_file"
            if [ $version_increment -gt 0 ]; then
                echo "[$pkg_name] Successfully downloaded newer version (patch +$version_increment)" >&2
            fi
            break
        fi

        # Exit code 22 means HTTP error (like 404)
        if [ $curl_exit_code -eq 22 ] && [ $version_increment -lt $MAX_VERSION_INCREMENTS ]; then
            echo "[$pkg_name] File not found (HTTP 404), trying next version..." >&2
            version_increment=$((version_increment + 1))
        else
            # Other error or exhausted version increments
            break
        fi
    done

    if [ "$download_success" = false ]; then
        echo "[$pkg_name] ERROR: Download failed after trying $((version_increment + 1)) version(s)" >&2
        rm -f "$rpm_file" "$current_rpm_file"
        return 1
    fi

    # Verify the downloaded file is a valid RPM
    if ! rpm2cpio "$rpm_file" >/dev/null 2>&1; then
        echo "[$pkg_name] ERROR: Downloaded file is not a valid RPM package" >&2
        rm -f "$rpm_file"
        return 1
    fi

    echo "[$pkg_name] Extracting into ${EXTRACT_DIR}..." >&2
    local extract_output=$(mktemp)
    mkdir -p "$EXTRACT_DIR"
    if ! rpm2cpio "$rpm_file" | ( cd "$EXTRACT_DIR" && cpio -idm ) 2>"$extract_output"; then
        echo "[$pkg_name] ERROR: Extraction failed" >&2
        cat "$extract_output" | head -10 | sed "s/^/[$pkg_name]   /" >&2
        rm -f "$extract_output" "$rpm_file"
        return 1
    fi
    rm -f "$extract_output" "$rpm_file"

    echo "[$pkg_name] Done" >&2
}

download_package_with_retry() {
    local pkg="$1"
    local html_page="$2"
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        echo "[$pkg] Attempt $attempt of $MAX_RETRIES" >&2

        if download_package "$pkg" "$html_page"; then
            return 0
        fi

        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "[$pkg] Retrying in 2 seconds..." >&2
            sleep 2
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

# Fetch the package listing for a given architecture and echo the path to the
# temporary HTML file holding it.
fetch_listing() {
    local arch="$1"
    local search_url="${REPO_BASE_URL}/${arch}/os/Packages/"

    echo "Fetching package list from: ${search_url}" >&2
    local html_page
    html_page=$(mktemp)

    if ! curl -L -s -f -A "$USER_AGENT" --max-time 90 --retry 2 -o "$html_page" "${search_url}"; then
        echo "ERROR: Failed to fetch package listing for ${arch}" >&2
        exit 1
    fi

    local html_size
    html_size=$(wc -c < "$html_page" 2>/dev/null || echo "0")
    echo "Downloaded ${html_size} bytes" >&2
    if [ "$html_size" -eq 0 ]; then
        echo "ERROR: Empty response from server for ${arch}" >&2
        exit 1
    fi

    echo "$html_page"
}

# Download a list of packages from a given listing/arch, failing fatally on the
# first package that cannot be fetched.
download_packages() {
    local html_page="$1"
    local arch="$2"
    shift 2

    ARCH="$arch"
    local pkg
    for pkg in "$@"; do
        echo "========================================" >&2
        if ! download_package_with_retry "$pkg" "$html_page"; then
            echo "FATAL: Failed to process package: $pkg after $MAX_RETRIES attempts" >&2
            exit 1
        fi
    done
    echo "========================================" >&2
}

# Symlink a set of shared libraries into usr/lib64/toolchain so the wrapped
# tools can find them via LD_LIBRARY_PATH. Patterns are relative to usr/lib64.
setup_toolchain_libdir() {
    echo "Setting up toolchain library directory..." >&2
    mkdir -p usr/lib64/toolchain

    shopt -s nullglob
    local pat lib
    for pat in "$@"; do
        for lib in usr/lib64/${pat}; do
            if [ -f "$lib" ]; then
                ln -sf "../$(basename "$lib")" usr/lib64/toolchain/
            fi
        done
    done
    shopt -u nullglob
}

# Mirror usr/lib64 -> lib64 and usr/lib -> lib as symlinks within the current
# directory. Linker scripts (and the libc.so GROUP script) contain absolute
# paths like /lib64/libc.so.6 and /lib/ld-linux-*.so which, once re-rooted by
# --sysroot, must resolve inside the (sys)root.
create_sysroot_symlinks() {
    echo "Creating sysroot lib/lib64 symlinks in $(pwd)..." >&2
    local d f filename
    for d in lib64 lib; do
        if [ -d "usr/$d" ]; then
            mkdir -p "$d"
            find "usr/$d" -type f | while read -r f; do
                filename=$(basename "$f")
                if [ ! -e "$d/$filename" ]; then
                    ln -s "../$f" "$d/$filename"
                fi
            done
        fi
    done
}

# Rewrite absolute paths in the target's GNU ld scripts (libc.so, libm.so, ...)
# to use ld's "=" sysroot prefix. glibc ships these as text linker scripts
# containing absolute GROUP/INPUT paths like /lib64/libc.so.6; the "=" prefix
# forces the linker to resolve them inside --sysroot instead of the host's
# /lib64 (which holds host-arch libraries). Operates on the current directory.
fix_sysroot_linker_scripts() {
    echo "Rewriting sysroot linker scripts to use the = sysroot prefix in $(pwd)..." >&2
    local f
    find usr/lib64 usr/lib -type f -name '*.so' 2>/dev/null | while read -r f; do
        # Only touch GNU ld text scripts, never real ELF shared objects.
        if head -c 64 "$f" 2>/dev/null | grep -q 'GNU ld script'; then
            sed -i -E 's@([ (])/(usr/)?lib(64)?/@\1=/\2lib\3/@g' "$f"
        fi
    done
}

# Wrap a single tool so it runs with the bundled PATH and LD_LIBRARY_PATH.
# Argument is the tool path relative to the repository root, e.g.
# usr/bin/gcc or usr/bin/aarch64-redhat-linux-gcc.
wrap_tool() {
    local tool_path="$1"
    if [ ! -f "$tool_path" ]; then
        return 0
    fi
    local tool_name
    tool_name=$(basename "$tool_path")

    cat > "${tool_path}_wrapper" <<'WRAPPER_EOF'
#!/bin/sh
SCRIPT_DIR="$(/usr/bin/dirname "$(/usr/bin/readlink -f "$0")")"
REPO_ROOT="$(/usr/bin/dirname "$(/usr/bin/dirname "$SCRIPT_DIR")")"
exec /usr/bin/env PATH="$REPO_ROOT/usr/bin:$PATH" LD_LIBRARY_PATH="$REPO_ROOT/usr/lib64/toolchain:$LD_LIBRARY_PATH" "$REPO_ROOT/usr/bin/TOOL_NAME_original" "$@"
WRAPPER_EOF

    sed -i "s/TOOL_NAME/$tool_name/g" "${tool_path}_wrapper"
    chmod +x "${tool_path}_wrapper"
    mv "$tool_path" "${tool_path}_original"
    mv "${tool_path}_wrapper" "$tool_path"
}

run_native_setup() {
    echo "Setting up AutoSD 10 GCC toolchain" >&2
    echo "Architecture: $ARCH" >&2
    echo "Repository: $REPO_URL" >&2
    echo "Packages: ${PACKAGES[*]}" >&2

    local html_page
    html_page=$(fetch_listing "$ARCH")
    trap "rm -f '$html_page'" EXIT

    echo "Downloading and extracting packages..." >&2
    download_packages "$html_page" "$ARCH" "${PACKAGES[@]}"

    echo "Setting up sysroot at: $(pwd)" >&2
    setup_toolchain_libdir \
        "libbfd*.so*" "libopcodes*.so*" "libctf*.so*" "libsframe*.so*" \
        "libmpc.so*" "libgmp.so*" "libmpfr.so*" "libjansson.so*" "libatomic*"

    echo "Creating sysroot structure..." >&2
    create_sysroot_symlinks

    echo "Creating binary wrappers..." >&2
    local tool
    for tool in gcc g++ cpp ar ld ld.bfd objcopy strip objdump as nm gcov; do
        wrap_tool "usr/bin/$tool"
    done

    echo "Applying linker fixes..." >&2
    if [ -f usr/bin/ld.bfd ] && [ ! -e usr/bin/ld ]; then
        ln -s ld.bfd usr/bin/ld
        echo "Created ld -> ld.bfd symlink" >&2
    fi

    # Write toolchain metadata at the root.
    cat > SYSROOT_INFO <<EOF
# AutoSD 10 GCC toolchain
MODE=native
ARCH=$ARCH
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
REPO_URL=$REPO_URL
PACKAGES=${PACKAGES[*]}
EOF
}

run_cross_setup() {
    local tool_tuple="${TARGET_ARCH}-redhat-linux"
    # Per-arch output directories: host tools in ./HOST_ARCH, target sysroot in
    # ./TARGET_ARCH. Named after the arch so the layout is self-describing.
    local host_dir="$HOST_ARCH"
    local target_dir="$TARGET_ARCH"
    echo "Setting up AutoSD 10 cross GCC toolchain (${HOST_ARCH} -> ${TARGET_ARCH})" >&2
    echo "Tool tuple: ${tool_tuple}-*" >&2
    echo "Host tools dir: ./${host_dir}   Target sysroot dir: ./${target_dir}" >&2

    # Refuse to extract into non-empty per-arch dirs (stale trees would mix).
    # Only these two subdirs are checked, so SYSROOT_DIR itself may be reused.
    local d
    for d in "$host_dir" "$target_dir"; do
        if [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
            echo "ERROR: ${SYSROOT_DIR}/${d} is not empty; choose a fresh directory" >&2
            exit 1
        fi
    done

    # AutoSD names the cross packages cross-<pkg>-<target arch> (e.g.
    # cross-gcc-aarch64). Expand the base names accordingly.
    local cross_tools=()
    local p
    for p in "${CROSS_TOOL_PACKAGES[@]}"; do
        cross_tools+=("${p}-${TARGET_ARCH}")
    done

    # 1. Cross tools + host support libraries (run on the host -> host repo),
    #    extracted into ./HOST_ARCH.
    local host_listing
    host_listing=$(fetch_listing "$HOST_ARCH")
    EXTRACT_DIR="$host_dir"
    mkdir -p "$host_dir"
    echo "Downloading cross tools and host support libraries..." >&2
    download_packages "$host_listing" "$HOST_ARCH" \
        "${cross_tools[@]}" "${CROSS_HOST_SUPPORT_PACKAGES[@]}"
    rm -f "$host_listing"

    # 2. Target sysroot (target libc / C++ runtime + headers -> target repo),
    #    extracted into ./TARGET_ARCH so it never mixes with the host tools.
    local target_listing
    target_listing=$(fetch_listing "$TARGET_ARCH")
    EXTRACT_DIR="$target_dir"
    mkdir -p "$target_dir"
    echo "Downloading target sysroot packages..." >&2
    download_packages "$target_listing" "$TARGET_ARCH" "${CROSS_SYSROOT_PACKAGES[@]}"
    rm -f "$target_listing"
    EXTRACT_DIR="."

    # Host-side: expose the cross tools' runtime deps (cc1/cc1plus need
    # libmpc/libmpfr/libgmp; ld needs libjansson) to the wrappers. Runs inside
    # ./HOST_ARCH since setup_toolchain_libdir operates on usr/lib64 relative to
    # the current directory.
    ( cd "$host_dir" && setup_toolchain_libdir \
        "libmpc.so*" "libgmp.so*" "libmpfr.so*" "libjansson.so*" )

    # Target sysroot: create the lib/lib64 symlinks the re-rooted libc.so GROUP
    # script and linker scripts rely on, then rewrite those scripts so their
    # absolute paths resolve inside the sysroot (not the host's /lib64).
    echo "Creating target sysroot structure..." >&2
    ( cd "$target_dir" && create_sysroot_symlinks && fix_sysroot_linker_scripts )

    # Wrap the prefixed cross tools so they find their sibling tools and the
    # bundled libjansson at runtime. The wrapper derives its root relative to the
    # tool, so it works unchanged from ./HOST_ARCH/usr/bin.
    echo "Creating binary wrappers..." >&2
    local tool
    for tool in gcc g++ cpp ar as ld ld.bfd nm objcopy objdump strip ranlib \
                gcc-ar gcc-nm gcc-ranlib gcov addr2line readelf; do
        wrap_tool "${host_dir}/usr/bin/${tool_tuple}-${tool}"
    done

    echo "Applying linker fixes..." >&2
    if [ -f "${host_dir}/usr/bin/${tool_tuple}-ld.bfd" ] && [ ! -e "${host_dir}/usr/bin/${tool_tuple}-ld" ]; then
        ln -s "${tool_tuple}-ld.bfd" "${host_dir}/usr/bin/${tool_tuple}-ld"
        echo "Created ${tool_tuple}-ld -> ${tool_tuple}-ld.bfd symlink" >&2
    fi

    # Write toolchain metadata at the root (host tools in HOST_ARCH/, target
    # libc in TARGET_ARCH/).
    cat > SYSROOT_INFO <<EOF
# AutoSD 10 cross GCC toolchain
MODE=cross
HOST_ARCH=$HOST_ARCH
TARGET_ARCH=$TARGET_ARCH
TOOL_TUPLE=${tool_tuple}
HOST_DIR=${host_dir}
TARGET_DIR=${target_dir}
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
REPO_BASE_URL=$REPO_BASE_URL
TOOL_PACKAGES=${cross_tools[*]} ${CROSS_HOST_SUPPORT_PACKAGES[*]}
SYSROOT_PACKAGES=${CROSS_SYSROOT_PACKAGES[*]}
EOF
}

if [ "$CROSS_MODE" = "true" ]; then
    run_cross_setup
else
    run_native_setup
fi

echo "Toolchain setup complete!" >&2
