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
"""Resolve RPM package names against repository indexes."""

_DIGITS = "0123456789"
_LETTERS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

def _version_key(version):
    """Order a VERSION or RELEASE using RPM's segment comparison rules."""

    # Segment order: tilde < end < caret < alphabetic < numeric.
    # A terminal segment makes prereleases older than their base version,
    # and snapshots newer than the base but older than its next segment.
    segments = []
    kind = 0
    start = 0
    for i in range(len(version) + 1):
        char = version[i] if i < len(version) else ""
        next_kind = 4 if char and char in _DIGITS else 3 if char and char in _LETTERS else 0
        if kind != next_kind:
            if kind:
                value = version[start:i]
                if kind == 4:
                    value = value.lstrip("0")
                segments.append((kind, len(value) if kind == 4 else 0, value))
            start = i
            kind = next_kind
        if char == "~":
            segments.append((0, 0, ""))
        elif char == "^":
            segments.append((2, 0, ""))

    segments.append((1, 0, ""))
    return tuple(segments)

def _rpm_filename_key(filename):
    # Compare VERSION before RELEASE, ignoring the package and architecture.
    # Epochs are not available in RPM filenames.
    nvr = filename.rsplit(".", 2)[0]
    _package, version, release = nvr.rsplit("-", 2)
    return (_version_key(version), _version_key(release), filename)

def _resolve_url(base_url, href):
    if "://" in href:
        return href
    if base_url.endswith("/"):
        return base_url + href
    return base_url + "/" + href

def find_rpm_url(content, base_url, package, arch):
    """Return the newest matching RPM's URL from an already-read index page.

    Args:
        content: HTML repository index.
        base_url: URL used to resolve relative links.
        package: Exact RPM package name.
        arch: Requested RPM architecture; noarch is also accepted.

    Returns:
        The URL of the RPM with the highest version and release.
    """
    prefix = "{}-".format(package)

    # Accept the requested arch plus `noarch` (used by header/data packages).
    suffixes = [".{}.rpm".format(arch), ".noarch.rpm"]

    found = {}
    for chunk in content.split('href="')[1:]:
        end = chunk.find('"')
        if end == -1:
            continue
        href = chunk[:end]
        if not href.endswith(".rpm"):
            continue
        name = href.split("/")[-1]

        ok_arch = False
        for suffix in suffixes:
            if name.endswith(suffix):
                ok_arch = True
                break
        if not ok_arch:
            continue

        # "<package>-<version>...": the char after "<package>-" must be a digit.
        # This distinguishes "zlib-ng-compat" from "zlib-ng-compat-devel".
        if not name.startswith(prefix):
            continue
        rest = name[len(prefix):]
        if len(rest) == 0 or rest[0] not in _DIGITS:
            continue

        found[name] = _resolve_url(base_url, href)

    names = sorted(found.keys(), key = _rpm_filename_key)
    if len(names) == 0:
        fail("autosd_rpm: no RPM found for package '{}' (arch {}) at {}".format(
            package,
            arch,
            base_url,
        ))
    if len(names) > 1:
        print("autosd_rpm: multiple RPMs matched '{}': {} -- using '{}'".format(
            package,
            names,
            names[-1],
        ))  # buildifier: disable=print
    return found[names[-1]]
