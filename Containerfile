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

FROM quay.io/fedora/fedora:42

ARG BAZEL_VERSION=8.3.0
ENV USE_BAZEL_VERSION=${BAZEL_VERSION}

RUN dnf install -y \
    curl \
    unzip \
    zip \
    git \
    java-21-openjdk \
    gcc \
    gcc-c++ \
    vim \
    && dnf clean all

RUN curl -Lo /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64 \
    && chmod +x /usr/local/bin/bazel

RUN bazel version
