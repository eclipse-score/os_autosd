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

AutoSD RPMs as Bazel Dependencies
=================================

You can use any of AutoSD's prebuilt binary RPMs as dependencies of your Bazel project
by using the ``autosd_dep`` rule.

Packages are fetched from the following locations:

* https://autosd.sig.centos.org/AutoSD-10/nightly/repos/AutoSD/compose/AutoSD/x86_64/os/Packages/
* https://autosd.sig.centos.org/AutoSD-10/nightly/repos/AutoSD/compose/AutoSD/aarch64/os/Packages/

Usage
-----

A full working example can be found at https://github.com/eclipse-score/os_autosd/tree/main/examples/autosd_dep_rpms.

This example fetches two packages (zlib and zlib-devel) into a single dir and is used as a dependency that uses
that library.

The next sections of this page have the content of each file, which has the following procedure:

- Include ``score_os_autosd`` bazel_dep and load its ``autosd_rpm`` rule
- Use ``autosd_rpm`` to fetch one or more packages
- Setup a BUILD file to indicate which RPM files need to be extracted (usually under ``third_party/<name>``  folder)
- Use that third_party label as a dependency of your build target

MODULE.bazel
************

.. code-block:: starlark

   bazel_dep(name = "score_os_autosd", version = "0.0.0")
   
   autosd_rpm = use_repo_rule("@score_os_autosd//rules/autosd_dep:defs.bzl", "autosd_rpm")
   
   autosd_rpm(
       name = "zlib-rpm",
       arch = "x86_64",
       build = "//third_party/zlib:zlib.BUILD",
       packages = [
           "zlib-ng-compat",  # provides usr/lib64/libz.so.1
           "zlib-ng-compat-devel",  # provides usr/include/zlib.h
       ],
       visibility = ["//visibility:public"],
   )

BUILD.bazel
***********

.. code-block:: starlark

   load("@rules_cc//cc:defs.bzl", "cc_binary")

   cc_binary(
       name = "zlib_demo",
       srcs = ["src/zlib_demo.c"],
       deps = ["//third_party/zlib"],
   )

third_party/zlib/BUILD.bazel
****************************

.. code-block:: starlark

   exports_files(["zlib.BUILD"])

   alias(
       name = "zlib",
       actual = "@zlib-rpm//:zlib",
       visibility = ["//visibility:public"],
   )

third_party/zlib/zlib.BUILD
****************************

.. code-block:: starlark

   load("@rules_cc//cc:defs.bzl", "cc_library")

   cc_library(
       name = "zlib",
       srcs = ["usr/lib64/libz.so.1"],
       hdrs = glob(["usr/include/**/*.h"]),
       includes = ["usr/include"],
       visibility = ["//visibility:public"],
   )

src/zlib_demo.c
***************

.. code-block:: c

   #include <stdio.h>
   #include <stdlib.h>
   #include <string.h>
   
   #include <zlib.h>
   
   int main(void) {
       const char *input = "hello from an AutoSD rpm, via zlib!";
       printf("zlib version: %s\n", zlibVersion());
   
       uLong src_len = (uLong)strlen(input) + 1; /* include terminating NUL */
       uLongf comp_len = compressBound(src_len);
       Bytef *comp = malloc(comp_len);
       if (comp == NULL)
           return 1;
   
       if (compress(comp, &comp_len, (const Bytef *)input, src_len) != Z_OK) {
           fprintf(stderr, "compress failed\n");
           return 1;
       }
   
       char out[256];
       uLongf out_len = sizeof(out);
       if (uncompress((Bytef *)out, &out_len, comp, comp_len) != Z_OK) {
           fprintf(stderr, "uncompress failed\n");
           return 1;
       }
   
       printf("compressed %lu -> %lu bytes, round-trip: \"%s\"\n",
              (unsigned long)src_len, (unsigned long)comp_len, out);
   
       free(comp);
       return strcmp(out, input) == 0 ? 0 : 1;
   } 
