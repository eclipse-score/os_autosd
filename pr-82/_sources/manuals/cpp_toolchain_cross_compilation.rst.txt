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

CPP Toolchain Cross Compilation
===============================

It's possible to build aarch64 targets in x86_64 hosts with by using the AutoSD Crossland toolchain.

The usage itself does not change, it's just  a matter to point to the right toolchain as seen in the following sections.

bazel_cpp_toolchains
--------------------

MODULE.bazel
************

.. code-block:: starlark

    bazel_dep(name = "score_bazel_cpp_toolchains", version = "x.x.x")

    ## AutoSD10 Toolchain
    gcc.toolchain(
        name = "score_autosd_10_cross_toolchain",
        runtime_ecosystem = "autosd10-crossland",
        target_cpu = "aarch64",
        target_os = "linux",
        use_default_package = True,
    )
    use_repo(
        gcc,
        "score_autosd_10_cross_toolchain",
    )


.bazelrc
********

.. code-block:: ini

   build:autosd-crossland --platforms=@score_bazel_platforms//:aarch64-linux-autosd10-crossland
   build:autosd-crossland --extra_toolchains=@score_autosd_10_cross_toolchain//:aarch64-linux-autosd10-crossland
   build:autosd-crossland --extra_toolchains=@score_toolchains_rust//toolchains/ferrocene:ferrocene_aarch64_unknown_linux_gnu


Standalone
----------

MODULE.bazel
************

.. code-block:: starlark

   bazel_dep(name = "score_os_autosd", version = "x.x.x")
   git_override(
     module_name = "score_os_autosd",
     remote = "https://github.com/eclipse-score/os_autosd",
     branch = "main",
   )

   # AutoSD cross GCC toolchain: tools run on the x86_64 host and emit aarch64 code.
   autosd_10_gcc_cross = use_extension("@score_os_autosd//toolchain/autosd_10_gcc:extensions.bzl", "autosd_10_gcc_cross_extension")
   autosd_10_gcc_cross.configure(
       c_flags = ["-fPIC"],
       cxx_flags = ["-fPIC"],
   )
   use_repo(autosd_10_gcc_cross, "autosd_10_gcc_cross_repo")

.bazelrc
********

.. code-block:: ini

   build:autosd-aarch64 --platforms=@score_os_autosd//toolchain:autosd10_aarch64
   build:autosd-aarch64 --extra_toolchains=@autosd_10_gcc_cross_repo//:cross_gcc_toolchain_x86_64_aarch64
   build:autosd-aarch64 --extra_toolchains=@autosd_10_gcc_repo//:gcc_toolchain_linux_x86_64

