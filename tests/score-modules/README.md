<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

#  AutoSD S-CORE Feature Module Tests

This repository contains the minimal setup to build s-core modules as external dependencies.

There are two kinds of patches:

* **ephemeral:** applies modifications to a module's MODULE.bazel file in order for it to build using AutoSD's toolchain;
* **fixes:**: these apply actual fixes in order to builda module's source code (usually adressing compilation errors).

All pactches can be found under the [./patches](./patches) folder. Patches were AI generated and human reviewed.
