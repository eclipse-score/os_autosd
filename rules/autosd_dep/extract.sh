#!/usr/bin/env bash
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
set -euo pipefail

rpm_file="$1"
out_file="$2"

# Keep the input reachable when the rpm2cpio fallback changes directories.
if [[ "${rpm_file}" != /* ]]; then
    rpm_file="${PWD}/${rpm_file}"
fi

if command -v rpm2archive >/dev/null 2>&1; then
    # Newer rpm2archive: uncompressed tar on stdout with -n.
    if rpm2archive -n "${rpm_file}" >"${out_file}" 2>/dev/null && [ -s "${out_file}" ]; then
        exit 0
    fi
    # Older rpm2archive: creates a gzipped "<rpm>.tar.gz" sibling file.
    if [ -f "${rpm_file}.tar.gz" ]; then
        gunzip -c "${rpm_file}.tar.gz" >"${out_file}"
        rm -f "${rpm_file}.tar.gz"
        exit 0
    fi
fi

# Fallback: rpm2cpio | cpio, then re-pack as an uncompressed tar so the caller
# always gets a uniform archive it can hand to repository_ctx.extract().
if command -v rpm2cpio >/dev/null 2>&1 && command -v cpio >/dev/null 2>&1; then
    workdir="$(mktemp -d)"
    trap 'rm -rf "${workdir}"' EXIT
    ( cd "${workdir}" && rpm2cpio "${rpm_file}" | cpio -idm --quiet )
    tar -cf "${out_file}" -C "${workdir}" .
    exit 0
fi

echo "extract.sh: need 'rpm2archive' (or 'rpm2cpio' + 'cpio') on PATH to unpack ${rpm_file}" >&2
exit 1
