# *******************************************************************************
# Copyright (c) 2024 Contributors to the Eclipse Foundation
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
load("@rules_rpm//:defs.bzl", "rpm_package")

rpm_package(
    name = "lola-demo",
    binaries = [
        "@score_communication//score/mw/com/example/ipc_bridge:ipc_bridge_cpp",
    ],
    config_dir = "/etc/lola",
    data = [
        "@score_communication//score/mw/com/example/ipc_bridge:etc/mw_com_config.json",
    ],
    data_dir = "/usr/share/lola/examples",
    description = "LOLA middleware communication libraries for development including core communication, configuration components, and example client/server binaries for testing",
    libraries = [
        "@score_communication//score/mw/com:com",
        "@score_communication//score/mw/com:config_schema",
    ],
    summary = "LOLA Demo",
    version = "1.0.0",
)

rpm_package(
    name = "persistency-demo",
    binaries = [
        "//demos/persistency:kvs-cpp-demo",
        "//demos/persistency:kvs-rust-demo",
    ],
    data = ["//demos/persistency:simple_demo.sh"],
    data_dir = "/usr/share/persistency-demo",
    description = "Comprehensive demonstration programs for Eclipse Score persistency Key-Value Storage (KVS) library showcasing capabilities through C++ and Rust implementations",
    libraries = [
        "@score_persistency//:kvs_cpp",
    ],
    summary = "Persistency KVS Demo",
    version = "0.1.0",
)

rpm_package(
    name = "holden-orchestrator-demo",
    binaries = [
        "//demos/holden:holden-orchestrator",
    ],
    description = "pidfd-based process orchestrator for managing and monitoring processes with automatic restart capability",
    summary = "Holden Process Orchestrator",
    version = "0.1.0",
)

rpm_package(
    name = "holden-agent-demo",
    binaries = [
        "//demos/holden:holden-agent",
    ],
    description = "Stateless process spawning agent for container-based process management",
    summary = "Holden Agent Daemon",
    version = "0.1.0",
)

rpm_package(
    name = "orchestrator-demo",
    binaries = [
        "@score_orchestrator//src/orchestration:basic",
        "@score_orchestrator//src/orchestration:main_macro_basic",
        "@score_orchestrator//src/orchestration:catch_error",
        "@score_orchestrator//src/orchestration:branching",
        "@score_orchestrator//src/orchestration:dag",
        "@score_orchestrator//src/orchestration:shutdown",
        "@score_orchestrator//src/orchestration:shutdown_using_signals",
        "@score_orchestrator//src/orchestration:events_across_local_programs",
        "@score_orchestrator//src/orchestration:inter_process_event_sender",
        "@score_orchestrator//src/orchestration:inter_process_event_receiver",
    ],
    description = "Orchestration framework",
    summary = "Orchestration Demo",
    version = "1.0.0",
)
