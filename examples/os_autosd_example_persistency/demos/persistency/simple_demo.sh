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

# Simple demonstration script for the KVS C++ library using the CLI tool
# This script shows the capabilities without needing to compile against score dependencies

set -e

echo "======================================="
echo "🚀 KVS Library Demonstration"
echo "======================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

print_header() {
    echo -e "${BLUE}=== $1 ===${RESET}"
}

print_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${RESET}"
}

print_cmd() {
    echo -e "${YELLOW}→ $1${RESET}"
}

# Create demo directory
DEMO_DIR="./kvs_demo_data"
mkdir -p "$DEMO_DIR"

print_info "Demo data directory: $DEMO_DIR"
echo ""

# Check if kvs-tool is available (optional for this demo)
if command -v kvs-tool >/dev/null 2>&1; then
    KVS_TOOL="kvs-tool"
    HAVE_CLI=true
    print_success "Found KVS CLI tool: $KVS_TOOL"
elif [ -f "../../target/release/kvs_tool" ]; then
    KVS_TOOL="../../target/release/kvs_tool"
    HAVE_CLI=true
    print_success "Found KVS CLI tool: $KVS_TOOL"
else
    HAVE_CLI=false
    print_info "kvs-tool not available (demo will show concepts only)"
fi
echo ""

print_header "Basic KVS Operations"

# Note: The actual KVS C++ library provides much richer functionality
# This demo uses the Rust CLI tool to show the concepts

print_info "The KVS C++ library provides:"
echo "  • Thread-safe key-value storage"
echo "  • Support for multiple data types (i32, u32, i64, u64, f64, bool, string, null, arrays, objects)"
echo "  • JSON-based persistence"
echo "  • Snapshot management"
echo "  • Default values handling"
echo "  • Builder pattern for configuration"
echo ""

print_info "Key features demonstrated by the C++ API:"
echo ""

echo "📝 C++ Code Example:"
echo "-------------------"
cat << 'EOF'
#include "kvsbuilder.hpp"

// Create KVS instance
auto kvs_result = KvsBuilder(InstanceId(0))
    .need_defaults_flag(false)
    .need_kvs_flag(false)
    .dir("./data")
    .build();

if (kvs_result) {
    Kvs kvs = std::move(kvs_result.value());

    // Set different data types
    kvs.set_value("temperature", KvsValue(23.5));
    kvs.set_value("active", KvsValue(true));
    kvs.set_value("name", KvsValue("sensor-01"));

    // Read values with type safety
    auto temp_result = kvs.get_value("temperature");
    if (temp_result) {
        auto temp = std::get<double>(temp_result.value().getValue());
        std::cout << "Temperature: " << temp << std::endl;
    }

    // Create snapshots
    kvs.flush();  // Creates snapshot automatically

    // List all keys
    auto keys = kvs.get_all_keys();

    // Restore from snapshot
    kvs.snapshot_restore(SnapshotId(1));
}
EOF
echo ""

print_header "KVS Library Features"

if [ "$HAVE_CLI" = true ]; then
    print_cmd "CLI tool available for testing: $KVS_TOOL"
    print_info "You can explore the KVS functionality using the CLI tool"
else
    print_info "CLI tool not available in this environment"
    print_info "The C++ library provides rich functionality as shown above"
fi

echo ""
print_info "Key C++ API Features:"
echo "  • Thread-safe operations with proper locking"
echo "  • Type-safe value access with std::variant"
echo "  • Automatic JSON persistence and loading"
echo "  • Builder pattern for easy configuration"
echo "  • Snapshot management (create/restore/manage)"
echo "  • Default values with CRC validation"
echo "  • Error handling with score::Result<T>"
echo ""

print_success "KVS Demo completed!"
print_info "For actual C++ integration, use:"
echo "  1. Include: #include \"kvsbuilder.hpp\""
echo "  2. Link against: libkvs_cpp.a, libkvs_internal.a, libkvsvalue.a"
echo "  3. Ensure score-baselibs dependencies are available"
echo ""

print_header "Installation"
echo "After building RPMs:"
echo "  • sudo dnf install persistency-cpp-devel-*.rpm    # C++ development"
echo "  • sudo dnf install persistency-cli-*.rpm         # CLI tool"
echo "  • sudo dnf install persistency-rust-devel-*.rpm  # Rust development"
echo ""

print_success "KVS C++ Library demonstration complete!"

# Clean up
rm -rf "$DEMO_DIR" 2>/dev/null || true
