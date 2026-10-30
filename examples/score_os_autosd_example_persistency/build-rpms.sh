# *******************************************************************************
# Copyright (c) 2025 Contributors to the Eclipse Foundation
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
#!/bin/bash

set -e

# Determine script directory and repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Allow override of build config
BUILD_CONFIG="${BUILD_CONFIG:-bl-x86_64-linux-autosd}"

# Output directory for RPMs
RPMS_DIR="${RPMS_DIR:-$REPO_ROOT/rpms}"

echo "Building RPMs with config: $BUILD_CONFIG"
echo "Output directory: $RPMS_DIR"

# Build all RPM packages
echo "Building lola-demo..."
bazel build --config="$BUILD_CONFIG" //:lola-demo

echo "Building persistency-demo..."
bazel build --config="$BUILD_CONFIG" //:persistency-demo

echo "Building holden packages..."
bazel build --config="$BUILD_CONFIG" //:holden-orchestrator-demo //:holden-agent-demo

echo "Building orchestrator-demo..."
bazel build --config="$BUILD_CONFIG" //:orchestrator-demo

# Create output directory
mkdir -p "$RPMS_DIR"

# Copy RPMs to output directory
echo "Copying RPMs to $RPMS_DIR..."
cp bazel-out/k8-fastbuild/bin/*.rpm "$RPMS_DIR/"

# Create repository metadata
echo "Creating repository metadata..."
createrepo_c "$RPMS_DIR/"

echo "Done! RPMs available at: $RPMS_DIR"
