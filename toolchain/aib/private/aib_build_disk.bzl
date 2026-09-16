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
load(":aib_common.bzl", "AibBuildInfo", "get_disk_ext", "get_oci_arch")

def _aib_build_disk_impl(ctx):
    disk_filename = "score-autosd-%s-%s-%s-%s.%s" % (ctx.label.name, ctx.attr.distro, ctx.attr.target, ctx.attr.arch, get_disk_ext(ctx))
    disk_file = ctx.actions.declare_file(disk_filename)
    gen_script = ctx.actions.declare_file("{}_generate.sh".format(ctx.label.name))

    ctx.actions.expand_template(
        template = ctx.file._tmpl,
        output = gen_script,
        substitutions = {
            "{{OCI_RUNTIME}}": ctx.attr.oci_runtime,
            "{{AIB_SCRIPT}}": ctx.file.aib_script.path,
            "{{AIB_BUILDER_IMAGE}}": ctx.file.aib_builder_image.path,
            "{{AIB_BOOTC_IMAGE}}": ctx.file.aib_bootc_image.path,
            "{{AIB_OUTPUT}}": disk_file.path,
        },
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [ctx.file.aib_script, ctx.file.aib_builder_image, ctx.file.aib_bootc_image],
        outputs = [disk_file],
        executable = gen_script,
        mnemonic = "AibBuildDisk",
        progress_message = "Generating disk file: %s" % disk_filename,
        use_default_shell_env = True,
        execution_requirements = {"no-sandbox": "1", "requires-network": "1"},
    )

    return [
        DefaultInfo(files = depset([disk_file])),
        AibBuildInfo(
            name = ctx.label.name,
            distro = ctx.attr.distro,
            arch = ctx.attr.arch,
            target = ctx.attr.target,
        ),
    ]

aib_build_disk = rule(
    implementation = _aib_build_disk_impl,
    attrs = {
        "_tmpl": attr.label(
            default = "//toolchain/aib/private/templates:aib_build_disk.sh.tmpl",
            allow_single_file = True,
        ),
        "oci_runtime": attr.string(
            default = "podman",
            doc = "OCI compatible runtime to use (podman, docker, etc)",
        ),
        "distro": attr.string(
            default = "autosd10",
            doc = "Distro name to build",
        ),
        "target": attr.string(
            mandatory = True,
            doc = "Target platform",
        ),
        "arch": attr.string(
            mandatory = True,
            doc = "Architecture to build against. Note that cross compilation is not supported.",
        ),
        "aib_builder_image": attr.label(
            allow_single_file = True,
            mandatory = False,
            doc = "OCI builder image to use (created by aib_build_builder)",
        ),
        "aib_bootc_image": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Bootc OCI image to generate a disk file from (created by aib_build_image)",
        ),
        "aib_script": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Generated AIB script from aib_script",
        ),
    },
)
