<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# AutoSD dependency example

This standalone Bazel project demonstrates `autosd_dep()` with the
[AutoSD 10 GCC toolchain](../../toolchain/README.md). It installs the zlib
development headers and library into the toolchain sysroot, compiles a C program,
and prints the compressed bytes of a static array as lowercase hex to stdout.
Packages are extracted into Bazel's external repository; they are not installed
into the host operating system.

## Dependencies

AutoSD 10 provides the `zlib-devel` capability through the
`zlib-ng-compat-devel` RPM. The toolchain's `autosd_dep()` tag accepts exact RPM
names, so [MODULE.bazel](MODULE.bazel) declares:

```starlark
autosd_10_gcc.autosd_dep(name = "zlib-ng-compat-devel")
autosd_10_gcc.autosd_dep(name = "zlib-ng-compat")
```

The second package supplies `libz.so.1`. It must be requested explicitly because
`autosd_dep()` does not resolve RPM dependencies automatically. The development
package supplies `zlib.h`, `zconf.h`, and the `libz.so` linker symlink. The
`zlib_compress` target uses `linkopts = ["-lz"]` to link against that library;
the toolchain already supplies the sysroot include and library search paths.

## Prerequisites

- A Linux x86_64 host capable of running the AutoSD 10 compiler binaries
  (glibc 2.39 or newer).
- Bazel 8.6.0, as pinned in `.bazelversion` (or Bazelisk).
- `rpm2cpio`, `cpio`, `bash`, `curl`, and standard GNU command-line utilities.
- Network access to the configured Bazel registries and the AutoSD nightly RPM
  repository. The first build downloads the compiler, sysroot, and zlib packages.
- A compatible `libz.so.1` installed on the machine where you run the program.
  On AutoSD 10 this is supplied by `zlib-ng-compat`.

## Build and run

From the repository root:

```sh
cd examples/autosd_dep
bazel build //:zlib_compress
bazel run //:zlib_compress
```

Run these commands from this directory so Bazel uses the example's module and
configuration. The module uses a local override for the parent `os_autosd`
checkout and registers its AutoSD 10 GCC toolchain. `.bazelrc` disables host C++
toolchain auto-detection.

The program compresses this 92-byte static array, excluding its terminating NUL:

```text
AutoSD dependencies with zlib! AutoSD dependencies with zlib! AutoSD dependencies with zlib!
```

It uses `compressBound()` to size the output buffer and `compress2()` with
`Z_BEST_COMPRESSION`. Successful output is one line of hex followed by a newline.
The exact compressed bytes can vary with the zlib implementation or version.
Allocation or compression failures are reported to stderr with a nonzero exit
status.

To save just the program's output after building:

```sh
./bazel-bin/zlib_compress > compressed.hex
```

The executable is dynamically linked. The sysroot provides libraries at build
time; running the executable requires compatible runtime libraries on the host
or an AutoSD 10 system.
