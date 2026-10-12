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
TARBALL_MODE=false
TARBALL_OUTPUT=""

if [ "${1:-}" = "--tarball" ]; then
    TARBALL_MODE=true
    if [ $# -lt 3 ]; then
        echo "ERROR: --tarball requires output path and architecture" >&2
        echo "Usage: $0 --tarball OUTPUT_PATH ARCH" >&2
        echo "       $0 ARCH" >&2
        exit 1
    fi
    TARBALL_OUTPUT="$2"
    shift 2
elif [ $# -lt 1 ]; then
    echo "ERROR: Missing architecture argument" >&2
    echo "Usage: $0 --tarball OUTPUT_PATH ARCH" >&2
    echo "       $0 ARCH" >&2
    exit 1
fi

ARCH="$1"
shift

# Setup working directory
WORK_DIR="$(pwd)"
if [ "$TARBALL_MODE" = "true" ]; then
    TEMP_DIR=$(mktemp -d -t autosd-toolchain-XXXXXX)
    echo "Working in temporary directory: $TEMP_DIR" >&2
    cd "$TEMP_DIR"
    trap 'cd "$WORK_DIR"; rm -rf "$TEMP_DIR"' EXIT
fi

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

# AutoSD 10 packages to download (versions discovered dynamically)
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

for package in "$@"; do
    package_is_present=false
    for configured_package in "${PACKAGES[@]}"; do
        if [ "$configured_package" = "$package" ]; then
            package_is_present=true
            break
        fi
    done

    if [ "$package_is_present" = false ]; then
        PACKAGES+=("$package")
    fi
done

USER_AGENT="Multi-GCC-Toolchain/1.0"
MAX_RETRIES=3
MAX_VERSION_INCREMENTS=1  # Try up to 1 patch version increments

echo "Setting up AutoSD 10 GCC toolchain" >&2
echo "Architecture: $ARCH" >&2
echo "Repository: $REPO_URL" >&2
echo "Packages: ${PACKAGES[*]}" >&2

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

    echo "[$pkg_name] Extracting..." >&2
    local extract_output=$(mktemp)
    if ! rpm2cpio "$rpm_file" | cpio -idm 2>"$extract_output"; then
        echo "[$pkg_name] ERROR: Extraction failed" >&2
        cat "$extract_output" | head -10 | sed "s/^/[$pkg_name]   /" >&2
        rm -f "$extract_output" "$rpm_file"
        return 1
    fi
    rm -f "$extract_output" "$rpm_file"

    echo "[$pkg_name] Done" >&2
}

# Fetch package listing once
search_url="${REPO_URL}/Packages/"

echo "Fetching package list from: ${search_url}" >&2
html_page=$(mktemp)
trap "rm -f '$html_page'" EXIT

if ! curl -L -s -f -A "$USER_AGENT" --max-time 90 --retry 2 -o "$html_page" "${search_url}"; then
    echo "ERROR: Failed to fetch package listing" >&2
    exit 1
fi

html_size=$(wc -c < "$html_page" 2>/dev/null || echo "0")
echo "Downloaded ${html_size} bytes" >&2

if [ "$html_size" -eq 0 ]; then
    echo "ERROR: Empty response from server" >&2
    exit 1
fi

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

echo "Downloading and extracting packages..." >&2
for pkg in "${PACKAGES[@]}"; do
    echo "========================================" >&2
    if ! download_package_with_retry "$pkg" "$html_page"; then
        echo "FATAL: Failed to process package: $pkg after $MAX_RETRIES attempts" >&2
        exit 1
    fi
done
echo "========================================" >&2

echo "Setting up sysroot at: $(pwd)" >&2
echo "Setting up toolchain library directory..." >&2
mkdir -p usr/lib64/toolchain

shopt -s nullglob
for lib_pattern in "libbfd*.so*" "libopcodes*.so*" "libctf*.so*" "libsframe*.so*" "libmpc.so*" "libgmp.so*" "libmpfr.so*" "libjansson.so*" "libatomic*"; do
    for lib in usr/lib64/${lib_pattern}; do
        if [ -f "$lib" ]; then
            ln -sf "../$(basename "$lib")" usr/lib64/toolchain/
        fi
    done
done
shopt -u nullglob

echo "Creating sysroot structure..." >&2
# Create lib64 and lib symlink directories to match linker script expectations
# Linker scripts contain paths like /lib64/libm.so.6 which resolve to <sysroot>/lib64/...
if [ -d usr/lib64 ]; then
    mkdir -p lib64
    find usr/lib64 -type f | while read -r f; do
        filename=$(basename "$f")
        if [ ! -e "lib64/$filename" ]; then
            ln -s "../$f" "lib64/$filename"
        fi
    done
fi

if [ -d usr/lib ]; then
    mkdir -p lib
    find usr/lib -type f | while read -r f; do
        filename=$(basename "$f")
        if [ ! -e "lib/$filename" ]; then
            ln -s "../$f" "lib/$filename"
        fi
    done
fi

echo "Creating binary wrappers..." >&2
for tool in gcc g++ cpp ar ld ld.bfd objcopy strip objdump as nm gcov; do
    tool_path="usr/bin/$tool"
    if [ ! -f "$tool_path" ]; then
        continue
    fi

    cat > "${tool_path}_wrapper" <<'WRAPPER_EOF'
#!/bin/sh
SCRIPT_DIR="$(/usr/bin/dirname "$(/usr/bin/readlink -f "$0")")"
REPO_ROOT="$(/usr/bin/dirname "$(/usr/bin/dirname "$SCRIPT_DIR")")"
exec /usr/bin/env PATH="$REPO_ROOT/usr/bin:$PATH" LD_LIBRARY_PATH="$REPO_ROOT/usr/lib64/toolchain:$LD_LIBRARY_PATH" "$REPO_ROOT/usr/bin/TOOL_NAME_original" "$@"
WRAPPER_EOF

    sed -i "s/TOOL_NAME/$tool/g" "${tool_path}_wrapper"
    chmod +x "${tool_path}_wrapper"
    mv "$tool_path" "${tool_path}_original"
    mv "${tool_path}_wrapper" "$tool_path"
done

echo "Applying linker fixes..." >&2
if [ -f usr/bin/ld.bfd ] && [ ! -e usr/bin/ld ]; then
    ln -s ld.bfd usr/bin/ld
    echo "Created ld -> ld.bfd symlink" >&2
fi

# Create tarball if requested
if [ "$TARBALL_MODE" = "true" ]; then
    # Resolve absolute path for output (since we're in temp dir)
    OUTPUT_PATH="$WORK_DIR/$TARBALL_OUTPUT"
    echo "Creating tarball: $OUTPUT_PATH" >&2

    # Create metadata file
    cat > SYSROOT_INFO <<EOF
# AutoSD 10 GCC Toolchain Sysroot
ARCH=$ARCH
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
REPO_URL=$REPO_URL
PACKAGES=${PACKAGES[*]}
EOF

    # Create sysroot directory and move contents
    mkdir -p sysroot
    mv usr SYSROOT_INFO sysroot/
    [ -d lib64 ] && mv lib64 sysroot/
    [ -d lib ] && mv lib sysroot/

    # Create tarball with sysroot contents
    tar -czf "$OUTPUT_PATH" sysroot

    echo "Tarball created successfully: $OUTPUT_PATH" >&2
    echo "Contents: usr/, lib64/, lib/, SYSROOT_INFO" >&2
fi

echo "Toolchain setup complete!" >&2
