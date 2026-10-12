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
load(
    ":toolchain_utils.bzl",
    "detect_gcc_version",
    "get_target_architecture",
)

def _autosd_10_gcc_toolchain_impl(repository_ctx):
    """Downloads AutoSD 10 RPM packages and creates an isolated GCC toolchain."""
    rpm_arch = get_target_architecture(repository_ctx)

    print("Setting up AutoSD 10 GCC toolchain for {}".format(rpm_arch))

    # Copy setup script to repository
    repository_ctx.template(
        "setup_toolchain.sh",
        Label("//toolchain/autosd_10_gcc:setup_toolchain.sh"),
        substitutions = {},
        executable = True,
    )

    # Run setup script with unbuffered output
    setup_args = ["bash", "./setup_toolchain.sh", rpm_arch] + repository_ctx.attr.autosd_deps

    result = repository_ctx.execute(setup_args, quiet = False)
    if result.return_code != 0:
        fail("Failed to setup toolchain: {}\n{}".format(result.stderr, result.stdout))

    # Detect GCC version
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Use flags passed from the extension (or defaults if none provided)
    autosd_flags = {
        "c_flags": getattr(repository_ctx.attr, "c_flags", []),
        "cxx_flags": getattr(repository_ctx.attr, "cxx_flags", []),
        "link_flags": getattr(repository_ctx.attr, "link_flags", []),
    }

    # Format flag lists for template substitution
    c_flags_str = ", ".join(['"{}"'.format(flag) for flag in autosd_flags.get("c_flags", [])])
    cxx_flags_str = ", ".join(['"{}"'.format(flag) for flag in autosd_flags.get("cxx_flags", [])])
    link_flags_str = ", ".join(['"{}"'.format(flag) for flag in autosd_flags.get("link_flags", [])])

    repository_ctx.template(
        "BUILD.bazel",
        Label("//toolchain/autosd_10_gcc:BUILD.bazel.template"),
        substitutions = {
            "{GCC_VERSION}": gcc_version,
            "{GCC_MAJOR}": gcc_major,
            "{TARGET_ARCH}": rpm_arch,
            "{C_FLAGS}": c_flags_str,
            "{CXX_FLAGS}": cxx_flags_str,
            "{LINK_FLAGS}": link_flags_str,
            "{GLIBC_CONSTRAINT}": "glibc_2_39_plus",
        },
    )

    # Copy shared template instead of generating dynamically
    repository_ctx.template(
        "cc_toolchain_config.bzl",
        Label("//toolchain/autosd_10_gcc:cc_toolchain_config.bzl.template"),
        substitutions = {
            "{REPO_NAME}": repository_ctx.name,
            "{DISTRO_NAME}": "autosd_10",
        },
    )

# Define the repository rule
autosd_10_gcc_toolchain = repository_rule(
    implementation = _autosd_10_gcc_toolchain_impl,
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"],
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the toolchain",
            default = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"],
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the toolchain",
            default = ["-Wl,-z,relro", "-Wl,-z,now"],
        ),
        "autosd_deps": attr.string_list(
            doc = "Additional AutoSD RPM packages to extract into the sysroot",
        ),
    },
    doc = "Repository rule for AutoSD 10 GCC toolchain",
)

def _autosd_10_gcc_extension_impl(module_ctx):
    """Extension implementation for AutoSD 10 GCC toolchain"""

    # Default flags from the repository rule
    default_c_flags = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"]
    default_cxx_flags = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"]
    default_link_flags = ["-Wl,-z,relro", "-Wl,-z,now"]

    # Create a separate toolchain for each module
    for i, mod in enumerate(module_ctx.modules):
        # Generate unique name for each module's toolchain
        toolchain_name = "autosd_10_gcc_repo" if i == 0 else "autosd_10_gcc_repo_{}".format(i)

        # Merge flags from all configure tags within this module
        c_flags = []
        cxx_flags = []
        link_flags = []
        autosd_deps = []
        replace_mode = False

        for config_tag in mod.tags.configure:
            if config_tag.replace:
                replace_mode = True
            c_flags.extend(config_tag.c_flags)
            cxx_flags.extend(config_tag.cxx_flags)
            link_flags.extend(config_tag.link_flags)

        for dependency_tag in mod.tags.autosd_dep:
            package_name = dependency_tag.name.strip()
            if not package_name:
                fail("autosd_dep name must not be empty")
            autosd_deps.append(package_name)

        # If not in replace mode, prepend defaults
        if not replace_mode:
            c_flags = default_c_flags + c_flags
            cxx_flags = default_cxx_flags + cxx_flags
            link_flags = default_link_flags + link_flags
        else:  # If in replace mode but no flags provided, use defaults
            if not c_flags:
                c_flags = default_c_flags
            if not cxx_flags:
                cxx_flags = default_cxx_flags
            if not link_flags:
                link_flags = default_link_flags

        autosd_10_gcc_toolchain(
            name = toolchain_name,
            c_flags = c_flags,
            cxx_flags = cxx_flags,
            link_flags = link_flags,
            autosd_deps = autosd_deps,
        )

_configure_tag = tag_class(
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the AutoSD 10 GCC toolchain",
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the AutoSD 10 GCC toolchain",
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the AutoSD 10 GCC toolchain",
        ),
        "replace": attr.bool(
            doc = "If True, replace default flags. If False (default), append to default flags.",
            default = False,
        ),
    },
    doc = "Configure compiler and linker flags for the AutoSD 10 GCC toolchain",
)

_autosd_dep_tag = tag_class(
    attrs = {
        "name": attr.string(
            doc = "Name of an additional AutoSD RPM package to extract into the sysroot",
            mandatory = True,
        ),
    },
    doc = "Add an AutoSD RPM package to the GCC toolchain sysroot",
)

autosd_10_gcc_extension = module_extension(
    implementation = _autosd_10_gcc_extension_impl,
    tag_classes = {
        "autosd_dep": _autosd_dep_tag,
        "configure": _configure_tag,
    },
    doc = "Extension for AutoSD 10 GCC toolchain",
)
