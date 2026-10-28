#!/usr/bin/env bash
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
set -euo pipefail

test_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$test_dir/../.." && pwd)
test_root=$(mktemp -d -t autosd-flags-tests-XXXXXX)
bazel_command=${BAZEL:-bazel}
cleanup() {
    if [[ -d "$test_root/bazel" && -d "$test_root/consumer" ]]; then
        (cd -- "$test_root/consumer" &&
            "$bazel_command" --output_user_root="$test_root/bazel" --nosystem_rc --nohome_rc \
                shutdown > /dev/null 2>&1) || true
    fi
    rm -rf -- "$test_root"
}
trap cleanup EXIT

# Reuse an extracted AutoSD sysroot, if provided, to avoid downloading RPMs for
# every configuration. Only package acquisition is substituted; the module
# extension, repository generation, compiler, and linker run as usual.
module_path=$repo_root
if [[ -n ${AUTOSD_TEST_SYSROOT:-} ]]; then
    module_path="$test_root/os_autosd"
    mkdir -p "$module_path"
    cp "$repo_root/MODULE.bazel" "$module_path/"
    cp -a "$repo_root/toolchain" "$module_path/"
    {
        printf '#!/usr/bin/env bash\nset -euo pipefail\n'
        printf 'cp -a --reflink=auto -- %q %q %q .\n' \
            "$AUTOSD_TEST_SYSROOT/usr" "$AUTOSD_TEST_SYSROOT/lib" "$AUTOSD_TEST_SYSROOT/lib64"
    } > "$module_path/toolchain/autosd_10_gcc/setup_toolchain.sh"
fi

consumer="$test_root/consumer"
mkdir -p "$consumer"
cp "$test_dir/BUILD.bazel" "$test_dir/helper.c" "$test_dir/smoke_test.cpp" "$consumer/"
cp "$repo_root/.bazelversion" "$consumer/"
cat > "$consumer/MODULE.bazel" <<EOF
module(name = "autosd_flags_consumer")
bazel_dep(name = "os_autosd", version = "0.0.0")
bazel_dep(name = "rules_cc", version = "0.2.17")
local_path_override(module_name = "os_autosd", path = $(jq -Rn --arg path "$module_path" '$path'))
autosd = use_extension("@os_autosd//toolchain/autosd_10_gcc:extensions.bzl", "autosd_10_gcc_extension")
include("//:configuration.MODULE.bazel")
use_repo(autosd, "autosd_10_gcc_repo")
EOF
cat > "$consumer/.bazelrc" <<EOF
common --registry=https://raw.githubusercontent.com/eclipse-score/bazel_registry/main/
common --registry=https://bcr.bazel.build
build --extra_toolchains=@autosd_10_gcc_repo//:gcc_toolchain_linux_$(uname -m)
build --jobs=4
test --test_output=errors
EOF
cd "$consumer"

run_bazel() {
    "$bazel_command" --output_user_root="$test_root/bazel" --nosystem_rc --nohome_rc "$@" --lockfile_mode=off
}

query_actions() {
    local configuration=$1
    local compilation_mode=$2
    shift 2
    # Included MODULE fragments have their own variable scope, but extension
    # usages with the same label/name share tags within the consuming module.
    printf '%s\n' \
        'autosd = use_extension("@os_autosd//toolchain/autosd_10_gcc:extensions.bzl", "autosd_10_gcc_extension")' \
        "$configuration" > configuration.MODULE.bazel
    run_bazel aquery 'mnemonic("CppCompile|CppLink", deps(//:smoke_test))' \
        -c "$compilation_mode" "$@" --output=jsonproto > "$test_root/actions.json"
}

assert_flag() {
    local source_suffix=$1
    local flag=$2
    jq -e --arg suffix "$source_suffix" --arg flag "$flag" '
        [.actions[] | select(.mnemonic == "CppCompile") |
            select(any(.arguments[]; endswith($suffix))) | .arguments] |
        length > 0 and all(.[]; index($flag) != null)
    ' "$test_root/actions.json" > /dev/null || {
        printf 'Missing compiler flag %s for %s\n' "$flag" "$source_suffix" >&2
        exit 1
    }
}

assert_no_flag() {
    local flag=$1
    jq -e --arg flag "$flag" 'all(.actions[]; .arguments | index($flag) == null)' \
        "$test_root/actions.json" > /dev/null || {
        printf 'Unexpected flag %s\n' "$flag" >&2
        exit 1
    }
}

assert_no_compile_flag() {
    local source_suffix=$1
    local flag=$2
    jq -e --arg suffix "$source_suffix" --arg flag "$flag" '
        [.actions[] | select(.mnemonic == "CppCompile") |
            select(any(.arguments[]; endswith($suffix))) | .arguments] |
        length > 0 and all(.[]; index($flag) == null)
    ' "$test_root/actions.json" > /dev/null || {
        printf 'Unexpected compiler flag %s for %s\n' "$flag" "$source_suffix" >&2
        exit 1
    }
}

assert_link_flag() {
    local flag=$1
    jq -e --arg flag "$flag" '
        [.actions[] | select(.mnemonic == "CppLink") | .arguments] |
        length > 0 and all(.[]; index($flag) != null)
    ' "$test_root/actions.json" > /dev/null || {
        printf 'Missing linker flag %s\n' "$flag" >&2
        exit 1
    }
}

query_actions '' dbg
assert_flag '.c' '-Wformat=2'
assert_flag '.cpp' '-Wformat=2'
assert_flag '.c' '-Wbad-function-cast'
assert_flag '.cpp' '-Wodr'
assert_no_compile_flag '.cpp' '-Wbad-function-cast'
assert_no_compile_flag '.c' '-Wodr'
assert_no_flag '-Wconversion'
assert_no_flag '-Werror'
assert_flag '.cpp' '-std=c++17'
assert_flag '.c' '-std=c11'
assert_flag '.cpp' '-fstack-protector'
assert_flag '.c' '-D_XOPEN_SOURCE=700'
assert_flag '.cpp' '-Og'
assert_flag '.c' '-g3'
assert_no_flag '-O2'
assert_no_flag '-pipe'
assert_link_flag '-Wl,-z,relro'
assert_link_flag '-Wl,-z,now'
assert_no_flag '-static-libstdc++'
run_bazel test //:smoke_test -c dbg

query_actions '' dbg --features=all_wall_warnings --features=warnings_as_errors
assert_flag '.cpp' '-Wformat=2'
assert_flag '.cpp' '-Wconversion'
assert_flag '.cpp' '-Warray-bounds=1'
assert_flag '.c' '-Wduplicate-decl-specifier'
assert_no_compile_flag '.cpp' '-Wduplicate-decl-specifier'
assert_flag '.cpp' '-Werror'
run_bazel test //:smoke_test -c dbg --features=all_wall_warnings --features=warnings_as_errors

query_actions '' dbg --features=-minimal_warnings
assert_no_flag '-Wformat=2'
assert_flag '.cpp' '-fstack-protector'

query_actions '' opt
assert_flag '.cpp' '-O2'
assert_flag '.c' '-DNDEBUG'
assert_no_flag '-Og'
run_bazel test //:smoke_test -c opt

query_actions '' fastbuild
assert_flag '.cpp' '-O2'
assert_flag '.c' '-DNDEBUG'

query_actions 'autosd.configure(use_score_flags = False)' dbg
assert_no_flag '-Wformat=2'
assert_no_flag '-fstack-protector'
assert_no_flag '-std=c++17'
assert_flag '.cpp' '-pipe'
assert_flag '.c' '-Werror=format-security'
run_bazel test //:smoke_test -c dbg

query_actions 'autosd.configure(c_flags = ["-DCUSTOM_C=1"], cxx_flags = ["-DCUSTOM_CXX=1", "-std=c++20", "-Wno-format"], link_flags = ["-Wl,--as-needed"], replace = True)' dbg
assert_flag '.c' '-DCUSTOM_C=1'
assert_flag '.cpp' '-DCUSTOM_CXX=1'
assert_flag '.cpp' '-fstack-protector'
assert_flag '.cpp' '-Wformat=2'
assert_link_flag '-Wl,--as-needed'
jq -e '
    [.actions[] | select(.mnemonic == "CppCompile") |
        select(any(.arguments[]; endswith(".cpp"))) | .arguments] |
    all(.[]; index("-std=c++20") > index("-std=c++17") and
        index("-Wno-format") > index("-Wformat=2"))
' "$test_root/actions.json" > /dev/null
run_bazel test //:smoke_test -c dbg

query_actions 'autosd.configure(use_score_flags = False, replace = True, c_flags = ["-O0"], cxx_flags = ["-O0", "-std=c++20"], link_flags = ["-Wl,--as-needed"])' dbg
assert_flag '.cpp' '-O0'
assert_flag '.c' '-O0'
assert_no_flag '-O2'
assert_no_flag '-pipe'
assert_no_flag '-fstack-protector'
assert_no_flag '-Werror=format-security'
assert_link_flag '-Wl,--as-needed'
run_bazel test //:smoke_test -c dbg

query_actions 'autosd.configure(use_score_flags = False, replace = True)' dbg
assert_flag '.cpp' '-pipe'
assert_flag '.c' '-O2'

printf 'AutoSD compiler flag inheritance tests passed.\n'
