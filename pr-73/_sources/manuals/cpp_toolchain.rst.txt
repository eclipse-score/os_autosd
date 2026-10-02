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

CPP Toolchain
=============

This toolchain modules provides the required tooling to build C++ projects in Eclipse S-CORE with Bazel.

Rust modules can be built with the upstream Ferrocene compilers.

System Requirements
-------------------

+-----------+-------------------------+
| Name      | Version (or Compatible) |
+===========+=========================+
| ``glibc`` | 2.39.x                  |
+-----------+-------------------------+


**NOTE:** The toolchain does not not support cross-compilation, so both execution and target platform architectures
must match while building Eclipse S-CORE modules with this toolchain.

Sysroot Packages
----------------

The following packages are installed in the toolchain's sysroot:

* gcc
* gcc-c++
* cpp
* binutils
* glibc-devel
* libstdc++-devel
* libstdc++
* kernel-headers
* glibc
* libgcc
* libmpc
* gmp
* mpfr
* jansson
* libatomic
* libtsan

These packages are available in the following CentOS Automotive SIG repositories:

- https://autosd.sig.centos.org/AutoSD-10/nightly/repos/AutoSD/compose/AutoSD/x86_64/os/Packages/
- https://autosd.sig.centos.org/AutoSD-10/nightly/repos/AutoSD/compose/AutoSD/aarch64/os/Packages/

Packages are downloaded and extracted into Bazel's syroot.

Usage
-----

This section describes how to build Eclipse S-CORE modules with AutoSD's toolchain using Bazel.

score_bazel_cpp_toolchains
**************************

The primary and recommended usage of this toolchain is to be used with https://github.com/eclipse-score/bazel_cpp_toolchains.
This way the toolchain will inherit whatever flags or rules are defined by that module.

This way of usage  

The first step is to add the toolchain in the main **MODULE.bazel** file:

.. code-block:: starlark

    bazel_dep(name = "score_bazel_cpp_toolchains", version = "0.5.2")

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


Then setup **.bazelrc** accordingly:

.. code-block:: ini

   build:autosd-x86_64 --force_pic
   build:autosd-x86_64 --platforms=@score_bazel_platforms//:x86_64-linux-autosd10
   build:autosd-x86_64 --extra_toolchains=@score_autosd10_x86_64_toolchain//:x86_64-linux-autosd10

   build:autosd-aarch64 --force_pic
   build:autosd-aarch64 --platforms=@score_bazel_platforms//:aarch64-linux-autosd10
   build:autosd-aarch64 --extra_toolchains=@score_autosd10_aarch64_toolchain//:aarch64-linux-autosd10

Standalone
**********

The toolchain can also be used as a direct Bazel dependency. Note that it will not use any rules or flags
defined by **score_bazel_cpp_toolchains** if doing so. The host system also needs the **rpm** tool in order
to extract all the required software into Bazel's sysroot.

MODULE.bazel content:

.. code-block:: starlark

   bazel_dep(name = "os_autosd", version = "1.0.0")

   git_override(
     module_name = "os_autosd",
     remote = "https://github.com/eclipse-score/inc_os_autosd",
     branch = "main",
   )

   autosd_10_gcc = use_extension("@os_autosd//toolchain/autosd_10_gcc:extensions.bzl", "autosd_10_gcc_extension")
   autosd_10_gcc.configure(
     c_flags = ["-fPIC"],
     cxx_flags = ["-fPIC"],
   )

   use_repo(autosd_10_gcc, "autosd_10_gcc_repo")


Also add the following to .bazelrc:

.. code-block:: ini

   build:autosd-x86_64 --extra_toolchains=@autosd_10_gcc_repo//:gcc_toolchain_linux_x86_64
