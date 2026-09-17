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
load(":aib_common.bzl", "AibBuildInfo", "get_oci_arch")

def _aib_build_builder_impl(ctx):
    oci_archive_name = "score-autosd-%s-builder-%s-%s.oci" % (ctx.label.name, ctx.attr.distro, get_oci_arch(ctx))
    oci_archive = ctx.actions.declare_file(oci_archive_name)
    gen_script = ctx.actions.declare_file("{}_generate.sh".format(ctx.label.name))

    ctx.actions.expand_template(
        template = ctx.file._tmpl,
        output = gen_script,
        substitutions = {
            "{{AIB_SCRIPT}}": ctx.file.aib_script.path,
            "{{IMG_DISTRO}}": ctx.attr.distro,
            "{{IMG_ARCH}}": ctx.attr.arch,
            "{{AIB_OUTPUT}}": oci_archive.path,
        },
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [ctx.file.aib_script],
        outputs = [oci_archive],
        executable = gen_script,
        mnemonic = "AibBuildBuilder",
        progress_message = "Building builder image with AIB: %s" % oci_archive_name,
        use_default_shell_env = True,
        execution_requirements = {"no-sandbox": "1", "requires-network": "1"},
    )

    return [
        DefaultInfo(files = depset([oci_archive])),
        AibBuildInfo(
            name = ctx.label.name,
            distro = ctx.attr.distro,
            arch = ctx.attr.arch,
        ),
    ]

aib_build_builder = rule(
    implementation = _aib_build_builder_impl,
    attrs = {
        "_tmpl": attr.label(
            default = "//toolchain/aib/private/templates:aib_build_builder.sh.tmpl",
            allow_single_file = True,
        ),
        "distro": attr.string(
            default = "autosd10",
            doc = "Distro name to build",
        ),
        "arch": attr.string(
            mandatory = False,
            doc = "Architecture to build against. Note that cross compilation is not supported.",
        ),
        "aib_script": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Generated AIB script from aib_script",
        ),
    },
)
