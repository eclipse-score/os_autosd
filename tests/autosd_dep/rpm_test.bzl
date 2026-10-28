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
"""Regression tests for RPM selection from repository indexes."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rules/autosd_dep:rpm.bzl", "find_rpm_url")

_BASE_URL = "https://example.invalid/Packages/"

def _version_order_test_impl(ctx):
    env = unittest.begin(ctx)

    # Each pair is (older, newer), including RPM-specific ordering rules.
    cases = [
        ("1.9-1", "1.10-1"),
        ("1.0-9.el10", "1.0-10.el10"),
        ("1.0-99", "1.0.1-1"),
        ("1.a-1", "1.0-1"),
        ("2.0~rc1-1", "2.0-1"),
        ("2.0-1", "2.0^20261028-1"),
        ("2.0^20261028-1", "2.0.1-1"),
        ("1.01-9", "01.1-10"),
        ("1.0beta2-1", "1.0beta10-1"),
        ("1.0-9", "1+0-10"),
        ("1.0-1~rc1", "1.0-1"),
    ]
    for older, newer in cases:
        old_rpm = "demo-lib-{}.x86_64.rpm".format(older)
        new_rpm = "demo-lib-{}.x86_64.rpm".format(newer)
        for names in [[old_rpm, new_rpm], [new_rpm, old_rpm]]:
            index = "\n".join(['<a href="{}">RPM</a>'.format(name) for name in names])
            asserts.equals(
                env,
                _BASE_URL + new_rpm,
                find_rpm_url(index, _BASE_URL, "demo-lib", "x86_64"),
                "Expected {} to be newer than {}".format(newer, older),
            )

    return unittest.end(env)

def _package_filter_test_impl(ctx):
    env = unittest.begin(ctx)
    index = "\n".join([
        '<a href="demo-lib-9.0-1.aarch64.rpm">wrong architecture</a>',
        '<a href="demo-lib-devel-9.0-1.x86_64.rpm">different package</a>',
        '<a href="demo-lib-1.9-1.x86_64.rpm">old</a>',
        '<a href="demo-lib-1.10-1.noarch.rpm">new</a>',
    ])
    asserts.equals(
        env,
        _BASE_URL + "demo-lib-1.10-1.noarch.rpm",
        find_rpm_url(index, _BASE_URL, "demo-lib", "x86_64"),
    )
    return unittest.end(env)

version_order_test = unittest.make(_version_order_test_impl)
package_filter_test = unittest.make(_package_filter_test_impl)

def rpm_test_suite(name):
    """Declare tests for RPM version ordering and package filtering."""
    unittest.suite(name, version_order_test, package_filter_test)
