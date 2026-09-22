# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
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

AibBuildInfo = provider(
    doc = "AutoSD's Automotive Image Builder Build Info",
    fields = {
        "name": "Image name (from Bazel rule)",
        "distro": "Distro pull RPMs from.",
        "target": "Targeted platform (qemu, etc).",
        "arch": "Architecture to build for, needs to match the hosts.",
    },
)

def get_oci_arch(ctx):
    oci_archs = {
        "x86_64": "amd64",
        "aarch64": "arm64",
    }

    return oci_archs.get(ctx.attr.arch, "amd64")

def get_disk_ext(ctx):
    targets = {
        "qemu": "qcow2",
    }

    return targets.get(ctx.attr.target, "img")

def validate_aib_include_dirs(ctx):
    manifest_dir = ctx.file.aib_manifest.dirname
    for f in ctx.files.aib_include_dirs:
        if not f.path.startswith(manifest_dir + "/"):
            fail("aib_include_dirs entry '%s' must live under the manifest directory '%s'" % (f.path, manifest_dir))
