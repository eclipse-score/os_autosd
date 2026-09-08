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

- `c_flags`: List of C compiler flags
- `cxx_flags`: List of C++ compiler flags
- `link_flags`: List of linker flags
- `replace`: Boolean (default: false). If true, replaces default flags; if false, appends to defaults
