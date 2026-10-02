..
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

OS AutoSD
=========

.. contents:: Table of Contents
   :local:

Overview
--------

This repository contains Bazel tools that are required to integrate AutoSD's toolchains into Eclipse S-CORE in order
to build modules for both x86_64 and aarch64.

Module Layout
-------------

The module template includes the following top-level structure:

.. code-block:: text

    <module_name>/                      # Root folder of the module, subfolder only if more than one module exists in the repository
    ├── .github/
    │   └── workflows/                  # CI/CD pipelines
    ├── docs/                           # Global documentation of the module
    │   ├── manuals/                    # Module manual, integration manual, table of assumptions of use,
    │   ├── release/                    # Module release note [wp__module_sw_release_note]
    │                                   #   module verifications [wp__verification_module_ver_report],
    ├── examples/                       # Usage examples for the module / features
    ├── tests/                          # Module tests
    ├── toolchain/                      # AutoSD toolchains defintions
    ├── MODULE.bazel                    # Bazel module definition
    ├── BUILD                           # Root build rules
    ├── project_config.bzl              # Project metadata used by Bazel macros
    └── README.md                       # Entry point of the repository

Module / Feature documentation overview
+++++++++++++++++++++++++++++++++++++++

.. toctree::

   manuals/index
   release/index

Examples
--------

MODULE.bazel
++++++++++++

.. code-block:: starlark

    bazel_dep(name = "score_bazel_cpp_toolchains", version = "0.5.5")

    gcc = use_extension("@score_bazel_cpp_toolchains//extensions:gcc.bzl", "gcc", dev_dependency = True)

    gcc.toolchain(
      name = "score_autosd10_x86_64_toolchain",
      runtime_ecosystem = "autosd10",
      target_cpu = "x86_64",
      target_os = "linux",
      use_default_package = True,
    )

    gcc.toolchain(
      name = "score_autosd10_aarch64_toolchain",
      runtime_ecosystem = "autosd10",
      target_cpu = "aarch64",
      target_os = "linux",
      use_default_package = True,
    )

    use_repo(
      gcc,
      "score_autosd10_aarch64_toolchain"
      "score_autosd10_x86_64_toolchain",
    )


.bazelrc
++++++++

.. code-block:: ini

   build:autosd-x86_64 --force_pic
   build:autosd-x86_64 --platforms=@score_bazel_platforms//:x86_64-linux-autosd10
   build:autosd-x86_64 --extra_toolchains=@score_autosd10_x86_64_toolchain//:x86_64-linux-autosd10

   build:autosd-aarch64 --force_pic
   build:autosd-aarch64 --platforms=@score_bazel_platforms//:aarch64-linux-autosd10
   build:autosd-aarch64 --extra_toolchains=@score_autosd10_aarch64_toolchain//:aarch64-linux-autosd10
