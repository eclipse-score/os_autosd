<!-- ----------------------------------------------------------------------------
  Copyright (c) 2025 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# Hello World (AArch64 cross build)

A minimal example that cross-compiles a C++ "hello world" into an **aarch64**
binary on an **x86_64** host, using the AutoSD GCC toolchain in *standalone*
mode (see `docs/manuals/cpp_toolchain.rst`).

It follows the manual's "Standalone" setup, except `os_autosd` is consumed from
the local checkout (`local_path_override` to `../../`) instead of a
`git_override`.

## Requirements

- An **x86_64** Linux host (the cross compiler runs on x86_64).
- `curl`, `rpm2cpio` and `cpio` on the host — the toolchain downloads and
  extracts RPMs into Bazel's sysroot on the first build.
- Network access to `autosd.sig.centos.org`.

## Build

The `.bazelrc` makes the aarch64 cross config the default, so:

```bash
cd examples/hello_world_arm
bazel build //:hello
```

(The first build is slow: it fetches the cross compiler plus the aarch64 sysroot.)

## Demos

The `demos/` folder is copied from `os_autosd_example_persistency` and wired to
cross-build (C/C++ targets only; the Rust demo was dropped).

| Target | Lang | Notes |
|---|---|---|
| `//:hello` | C++ | Minimal, self-contained. |
| `//demos/holden:holden-agent` | C | Self-contained. |
| `//demos/holden:holden-orchestrator` | C | Self-contained. |
| `//demos/persistency:kvs-cpp-demo` | C++ | Depends on `@score_persistency` (pulls in the full score module tree via `score_modules.MODULE.bazel`). |

```bash
# Self-contained C/C++ demos (verified path):
bazel build //:hello //demos/holden:all

# C++ demo that pulls the score module stack:
bazel build //demos/persistency:kvs-cpp-demo

# Everything:
bazel build //...
```

> The `hello` and `holden` targets are self-contained and build directly with
> the cross toolchain. `kvs-cpp-demo` additionally cross-compiles the whole
> `score_persistency`/`score_baselibs` tree; that larger build is wired the same
> way the persistency example wires it (see `score_modules.MODULE.bazel`,
> `patches/`, and the `score_baselibs` flags in `.bazelrc`) but is not verified
> here and may need further fixups to cross-compile cleanly. The native x86_64
> toolchain is also registered so any host/exec-config build tools pulled in by
> those modules have a matching toolchain.

## Verify it is an AArch64 binary

```bash
file "$(bazel cquery --output=files //:hello 2>/dev/null)"
# => ELF 64-bit LSB pie executable, ARM aarch64, ...
```

To confirm toolchain resolution picked the cross toolchain:

```bash
bazel build //:hello \
  --toolchain_resolution_debug='@bazel_tools//tools/cpp:toolchain_type'
```

To actually *run* the binary on an x86_64 machine you need an emulator
(`qemu-aarch64`), pointed at the toolchain's aarch64 sysroot with `-L` (the
sysroot lives under `bazel info output_base`/external/ in the
`autosd_10_gcc_cross_repo` directory's `sysroot/`).

## How it works

- `MODULE.bazel` pulls in the local `os_autosd` and uses the
  `autosd_10_gcc_cross_extension`, producing `@autosd_10_gcc_cross_repo`.
- `.bazelrc` sets `--platforms=@os_autosd//toolchain:autosd10_aarch64` (target
  aarch64) and registers `cross_gcc_toolchain_x86_64_aarch64` via
  `--extra_toolchains`. The host/exec platform stays the x86_64 host, which
  matches the cross toolchain's exec constraints — so Bazel selects it only for
  the aarch64 target.

> This example registers only the cross toolchain. If you extend it with targets
> that must also build host tools from C/C++, additionally register the native
> toolchain, e.g. add
> `--extra_toolchains=@autosd_10_gcc_repo//:gcc_toolchain_linux_x86_64`
> (and the matching `use_extension`/`use_repo` for `autosd_10_gcc_extension`).
