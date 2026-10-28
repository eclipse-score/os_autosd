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
"""Generate AutoSD GCC toolchains with optional S-CORE warning policies."""

load(
    ":toolchain_utils.bzl",
    "detect_gcc_version",
    "get_target_architecture",
)

_STANDALONE_COMPILE_FLAGS = ["-O2", "-g", "-pipe", "-Wall", "-Werror=format-security"]
_DEFAULT_LINK_FLAGS = ["-Wl,-z,relro", "-Wl,-z,now"]

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
    setup_args = ["bash", "-c", "exec ./setup_toolchain.sh '{}'".format(rpm_arch)]

    result = repository_ctx.execute(setup_args, quiet = False)
    if result.return_code != 0:
        fail("Failed to setup toolchain: {}\n{}".format(result.stderr, result.stdout))

    # Detect GCC version
    gcc_version, gcc_major = detect_gcc_version(repository_ctx)

    # Keep defaults for direct repository-rule callers as well as extension users.
    default_compile_flags = [] if repository_ctx.attr.use_score_flags else _STANDALONE_COMPILE_FLAGS
    autosd_flags = {
        "c_flags": repository_ctx.attr.c_flags or default_compile_flags,
        "cxx_flags": repository_ctx.attr.cxx_flags or default_compile_flags,
        "link_flags": repository_ctx.attr.link_flags or _DEFAULT_LINK_FLAGS,
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
            "{USE_SCORE_FLAGS}": str(repository_ctx.attr.use_score_flags),
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
            # Resolve dependencies in this module, including for consumers that
            # do not declare rules_cc or score_cpp_policies themselves.
            "{FEATURE_INJECTION_BZL}": str(Label("@rules_cc//cc/toolchains:feature_injection.bzl")),
            "{MINIMAL_WARNINGS}": str(Label("@score_cpp_policies//warnings/gcc/features:minimal_warnings")),
            "{STRICT_WARNINGS}": str(Label("@score_cpp_policies//warnings/gcc/features:strict_warnings")),
            "{ALL_WALL_WARNINGS}": str(Label("@score_cpp_policies//warnings/gcc/features:all_wall_warnings")),
            "{WARNINGS_AS_ERRORS}": str(Label("@score_cpp_policies//warnings/gcc/features:warnings_as_errors")),
        },
    )

# Define the repository rule
autosd_10_gcc_toolchain = repository_rule(
    implementation = _autosd_10_gcc_toolchain_impl,
    attrs = {
        "c_flags": attr.string_list(
            doc = "C compiler flags for the toolchain",
        ),
        "cxx_flags": attr.string_list(
            doc = "C++ compiler flags for the toolchain",
        ),
        "link_flags": attr.string_list(
            doc = "Linker flags for the toolchain",
        ),
        "use_score_flags": attr.bool(
            doc = "Use S-CORE warning policies and AutoSD compiler defaults",
            default = True,
        ),
    },
    doc = "Repository rule for AutoSD 10 GCC toolchain",
)

def _autosd_10_gcc_extension_impl(module_ctx):
    """Extension implementation for AutoSD 10 GCC toolchain"""

    # Create a separate toolchain for each module
    for i, mod in enumerate(module_ctx.modules):
        # Generate unique name for each module's toolchain
        toolchain_name = "autosd_10_gcc_repo" if i == 0 else "autosd_10_gcc_repo_{}".format(i)

        # Merge flags from all configure tags within this module
        c_flags = []
        cxx_flags = []
        link_flags = []
        replace_mode = False
        use_score_flags = True

        for config_tag in mod.tags.configure:
            if config_tag.replace:
                replace_mode = True
            if not config_tag.use_score_flags:
                use_score_flags = False
            c_flags.extend(config_tag.c_flags)
            cxx_flags.extend(config_tag.cxx_flags)
            link_flags.extend(config_tag.link_flags)

        # Compiler defaults are applied as mode-dependent features, alongside
        # S-CORE warnings. The AutoSD SDK uses a dynamic C++ runtime.
        default_compile_flags = [] if use_score_flags else _STANDALONE_COMPILE_FLAGS
        if not replace_mode:
            c_flags = default_compile_flags + c_flags
            cxx_flags = default_compile_flags + cxx_flags
            link_flags = _DEFAULT_LINK_FLAGS + link_flags
        else:  # Preserve the existing fallback for empty replacement lists.
            if not c_flags:
                c_flags = default_compile_flags
            if not cxx_flags:
                cxx_flags = default_compile_flags
            if not link_flags:
                link_flags = _DEFAULT_LINK_FLAGS

        autosd_10_gcc_toolchain(
            name = toolchain_name,
            c_flags = c_flags,
            cxx_flags = cxx_flags,
            link_flags = link_flags,
            use_score_flags = use_score_flags,
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
            doc = "Replace standalone compiler and AutoSD linker defaults. Policy warnings and AutoSD compiler defaults remain active.",
            default = False,
        ),
        "use_score_flags": attr.bool(
            doc = "Use S-CORE warning policies and AutoSD compiler defaults. If any configure tag sets False, use standalone compiler defaults instead.",
            default = True,
        ),
    },
    doc = "Configure compiler and linker flags for the AutoSD 10 GCC toolchain",
)

autosd_10_gcc_extension = module_extension(
    implementation = _autosd_10_gcc_extension_impl,
    tag_classes = {
        "configure": _configure_tag,
    },
    doc = "Extension for AutoSD 10 GCC toolchain",
)
