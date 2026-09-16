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
load(":aib_common.bzl", "AibBuildInfo", "get_oci_arch", "validate_aib_include_dirs")

def _aib_build_image_impl(ctx):
    oci_archive_name = "score-autosd-%s-bootc-%s-%s-%s.oci" % (ctx.label.name, ctx.attr.distro, ctx.attr.target, get_oci_arch(ctx))
    oci_archive = ctx.actions.declare_file(oci_archive_name)
    gen_script = ctx.actions.declare_file("{}_generate.sh".format(ctx.label.name))

    validate_aib_include_dirs(ctx)

    ctx.actions.expand_template(
        template = ctx.file._tmpl,
        output = gen_script,
        substitutions = {
            "{{OCI_RUNTIME}}": ctx.attr.oci_runtime,
            "{{AIB_SCRIPT}}": ctx.file.aib_script.path,
            "{{IMG_DISTRO}}": ctx.attr.distro,
            "{{IMG_TARGET}}": ctx.attr.target,
            "{{IMG_ARCH}}": ctx.attr.arch,
            "{{AIB_MANIFEST}}": ctx.file.aib_manifest.path,
            "{{AIB_DEFINE_FILES}}": " ".join([f.path for f in ctx.files.aib_define_files]),
            "{{AIB_OUTPUT}}": oci_archive.path,
        },
        is_executable = True,
    )

    ctx.actions.run(
        inputs = [ctx.file.aib_script, ctx.file.aib_manifest] + ctx.files.aib_define_files + ctx.files.aib_include_dirs,
        outputs = [oci_archive],
        executable = gen_script,
        mnemonic = "AibBuild",
        progress_message = "Building with AIB: %s" % oci_archive_name,
        use_default_shell_env = True,
        execution_requirements = {"no-sandbox": "1", "requires-network": "1"},
    )

    return [
        DefaultInfo(files = depset([oci_archive])),
        AibBuildInfo(
            name = ctx.label.name,
            distro = ctx.attr.distro,
            target = ctx.attr.target,
            arch = ctx.attr.arch,
        ),
    ]

aib_build_image = rule(
    implementation = _aib_build_image_impl,
    attrs = {
        "_tmpl": attr.label(
            default = "//toolchain/aib/private/templates:aib_build_image.sh.tmpl",
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
        "aib_script": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "Generated AIB script from aib_script",
        ),
        "aib_manifest": attr.label(
            allow_single_file = True,
            mandatory = True,
            doc = "AIB image manifest file, requires for aib_image_type=image",
        ),
        "aib_define_files": attr.label_list(
            allow_files = True,
            default = [],
            doc = "Variables file list to use when building an image",
        ),
        "aib_include_dirs": attr.label_list(
            allow_files = True,
            default = [],
            doc = "Files to be included by the AIB manifest file",
        ),
    },
)
