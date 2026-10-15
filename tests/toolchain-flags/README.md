<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# Direct-module compiler flag tests

Run from the repository root:

```sh
bash tests/toolchain-flags/run-tests.sh
```

The script creates an independent Bazel consumer of `os_autosd` and inspects its
actual C, C++, and linker actions with `bazel aquery`. It checks inherited flags
in debug, optimized, and fastbuild configurations, opt-out, custom flag ordering,
and replacement of standalone defaults. It also compiles, links, and runs a
mixed C/C++ test in the debug, optimized, opt-out, and custom configurations.

Requirements are Bazel, `jq`, the tools used by `setup_toolchain.sh`, a Linux
host matching the target architecture, and the host glibc version required by
the AutoSD compiler. Set `BAZEL` to use a specific Bazel executable.

To reuse an already extracted AutoSD sysroot and avoid downloading RPMs for each
configuration:

```sh
AUTOSD_TEST_SYSROOT=/path/to/sysroot bash tests/toolchain-flags/run-tests.sh
```

This mode copies the module into a temporary directory and substitutes only the
package setup script. The real module extension and toolchain generation still
run, using the supplied AutoSD compiler and libraries. All test files and Bazel
outputs are created in a temporary directory.
