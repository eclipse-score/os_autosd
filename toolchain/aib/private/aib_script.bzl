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
AibScriptInfo = provider(
    doc = "Carries the aib wrapper script file.",
    fields = {
        "script_path": "Label to an existing generated aib script.",
        "oci_image": "OCI image to generate an aib script.",
        "oci_runtime": "OCI runtime (docker, podman, etc) to use.",
    },
)

def _aib_script_impl(ctx):
    aib_script = ctx.file.script_path

    if not aib_script:
        aib_script = ctx.actions.declare_file("aib.{}.generated.sh".format(ctx.label.name))
        gen_script = ctx.actions.declare_file("{}_generated.sh.tmpl".format(ctx.label.name))

        ctx.actions.expand_template(
            template = ctx.file._tmpl,
            output = gen_script,
            substitutions = {
                "{{AIB_OCI_RUNTIME}}": ctx.attr.oci_runtime,
                "{{AIB_OCI_IMAGE}}": ctx.attr.oci_image,
                "{{AIB_SCRIPT_PATH}}": aib_script.path,
            },
            is_executable = True,
        )

    ctx.actions.run(
        outputs = [aib_script],
        executable = gen_script,
        mnemonic = "AibScriptGen",
        progress_message = "Generating aib wrapper script from %s" % ctx.attr.oci_image,
        use_default_shell_env = True,
        execution_requirements = {"no-sandbox": "1", "requires-network": "1"},
    )

    return [
        DefaultInfo(files = depset([aib_script])),
        AibScriptInfo(script_path = aib_script),
    ]

aib_script = rule(
    implementation = _aib_script_impl,
    attrs = {
        "_tmpl": attr.label(
            default = "//toolchain/aib/private/templates:aib_script.sh.tmpl",
            allow_single_file = True,
        ),
        "script_path": attr.label(
            mandatory = False,
            allow_single_file = True,
            doc = "Label to an existing generated aib script",
        ),
        "oci_image": attr.string(
            mandatory = False,
            default = "quay.io/centos-sig-automotive/automotive-image-builder:latest",
            doc = "OCI image to generate an aib script",
        ),
        "oci_runtime": attr.string(
            mandatory = False,
            default = "/usr/bin/podman",
            doc = "OCI runtime (docker, podman, etc) to use",
        ),
    },
)
