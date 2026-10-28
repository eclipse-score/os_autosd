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
"""Exercise the rpm2cpio fallback with a real RPM (requires rpmbuild)."""

import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest


class ExtractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="autosd-extract-test-")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.script = (
            Path(__file__).parents[3] / "rules/autosd_dep/extract.sh"
        ).resolve()

        # Use the real unpacking tools, with rpm2archive absent from PATH.
        cls.bin_dir = cls.root / "bin"
        cls.bin_dir.mkdir()
        for tool in ("bash", "rpm2cpio", "cpio", "mktemp", "rm", "tar"):
            executable = shutil.which(tool)
            if executable is None:
                raise RuntimeError(f"Test requires {tool} on PATH")
            (cls.bin_dir / tool).symlink_to(executable)

        spec = cls.root / "fixture.spec"
        spec.write_text(
            "Name: autosd-extract-test\n"
            "Version: 1.0\n"
            "Release: 1\n"
            "Summary: RPM extraction test fixture\n"
            "License: Apache-2.0\n"
            "BuildArch: noarch\n"
            "%description\n"
            "A small payload for extraction regression tests.\n"
            "%install\n"
            "mkdir -p %{buildroot}/usr/share/autosd-extract-test\n"
            "printf 'extracted payload\\n' > %{buildroot}/usr/share/autosd-extract-test/payload.txt\n"
            "%files\n"
            "/usr/share/autosd-extract-test/payload.txt\n"
        )
        build = subprocess.run(
            [
                "rpmbuild",
                "--define",
                f"_topdir {cls.root}/rpmbuild",
                "--define",
                f"_tmppath {cls.root}",
                "--define",
                "source_date_epoch_from_changelog 0",
                "--define",
                "__os_install_post %{nil}",
                "-bb",
                str(spec),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if build.returncode:
            raise RuntimeError(build.stdout + build.stderr)
        cls.rpm = next((cls.root / "rpmbuild/RPMS/noarch").glob("*.rpm"))

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(
            prefix="working directory ", dir=self.root
        )
        self.addCleanup(temporary.cleanup)
        self.workdir = Path(temporary.name)
        self.input_rpm = self.workdir / "package with spaces.rpm"
        shutil.copyfile(self.rpm, self.input_rpm)

    def assert_extracts(self, rpm_path, cwd):
        result = subprocess.run(
            [
                str(self.bin_dir / "bash"),
                str(self.script),
                str(rpm_path),
                "result with spaces.tar",
            ],
            cwd=cwd,
            env={**os.environ, "PATH": str(self.bin_dir)},
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with tarfile.open(cwd / "result with spaces.tar") as archive:
            payload = archive.extractfile("./usr/share/autosd-extract-test/payload.txt")
            self.assertIsNotNone(payload)
            self.assertEqual(payload.read(), b"extracted payload\n")

    def test_relative_rpm_path(self):
        self.assert_extracts(self.input_rpm.name, self.workdir)

    def test_absolute_rpm_path(self):
        self.assert_extracts(self.input_rpm, self.workdir)

    def test_parent_relative_rpm_path(self):
        child = self.workdir / "child"
        child.mkdir()
        self.assert_extracts(Path("..") / self.input_rpm.name, child)


if __name__ == "__main__":
    unittest.main()
