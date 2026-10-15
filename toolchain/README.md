<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# AutoSD Toolchains

This directory contains Bazel toolchain definitions for building with AutoSD GCC compilers.

The direct Bazel module uses the compiler flag definitions from
`score_bazel_cpp_toolchains` by default. Its flags for `dbg`, `opt`, and `fastbuild`
are applied according to the selected Bazel compilation mode. AutoSD's sysroot,
compiler paths, and include directories are configured in every mode.
AutoSD's linker defaults are retained because its SDK uses a dynamic C++ runtime.

## Usage

### In your MODULE.bazel

```python
# Use local path during development, or git_override for published versions
local_path_override(
    module_name = "os_autosd",
    path = "/path/to/inc_os_autosd/"
)

bazel_dep(name = "os_autosd", version = "1.0.0")

# Configure AutoSD 10 GCC toolchain
autosd_10_gcc = use_extension("@os_autosd//toolchain/autosd_10_gcc:extensions.bzl", "autosd_10_gcc_extension")
autosd_10_gcc.configure(
    c_flags = ["-Wall", "-Wno-error=deprecated-declarations", "-Werror", "-fPIC"],
    cxx_flags = ["-Wall", "-Wno-error=deprecated-declarations", "-Werror", "-fPIC"],
)

use_repo(autosd_10_gcc, "autosd_10_gcc_repo")
register_toolchains("@autosd_10_gcc_repo//:gcc_toolchain_linux_x86_64")
```

### In your .bazelrc

To disable Bazel's auto-detection of the system C++ toolchain:

```
build --incompatible_enable_cc_toolchain_resolution
build --repo_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1
```

## Available Toolchains

- **AutoSD 10 GCC**: `@os_autosd//toolchain/autosd_10_gcc`

## Configuration Options

The `configure` tag accepts the following attributes:

- `c_flags`: Additional C compiler flags
- `cxx_flags`: Additional C++ compiler flags
- `link_flags`: Additional linker flags
- `use_score_flags`: Boolean (default: true). Inherit S-CORE compiler
  flags. If any `configure` tag for a module sets this to false, that module's
  toolchain uses the previous standalone defaults instead.
- `replace`: Boolean (default: false). Replace standalone compiler defaults and
  AutoSD linker defaults for each nonempty custom flag list. Empty lists keep
  their defaults. Inherited S-CORE compiler flags remain active; custom compiler
  flags are appended after them, regardless of `replace`.

Custom flags appear after inherited flags, so a setting such as
`cxx_flags = ["-std=c++20"]` can override the inherited language standard.

To disable S-CORE flags in your `MODULE.bazel`:

```starlark
autosd_10_gcc.configure(use_score_flags = False)
```

For a custom policy, combine `use_score_flags = False` with `replace = True` and
provide the desired C, C++, and linker flags. Sysroot and include-path settings
remain active.
