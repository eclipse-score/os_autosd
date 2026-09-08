# rules_aib

`rules_aib` is a small Bazel rule set for building AutoSD images with
[Automotive Image Builder (AIB)][aib-docs]. It lets Bazel targets describe the
AIB builder image, generate an AIB manifest from rule attributes, and run AIB
with either a generated or existing manifest to produce a target image artifact.

The public API is exported from `@rules_aib//:defs.bzl`:

```python
load("@rules_aib//:defs.bzl", "aib_build", "aib_build_builder", "aib_manifest")
```

## Requirements

The build actions run AIB and `podman` locally with Bazel sandboxing disabled.
The selected AIB executable must be available on `PATH`, or passed through the
`aib` parameter of `aib_build_builder`.

## Basic Usage

Define a builder and manifest target, then use them from an image target:

```python
load("@rules_aib//:defs.bzl", "aib_build", "aib_build_builder", "aib_manifest")

aib_build_builder(
    name = "builder",
)

aib_manifest(
    name = "manifest",
    image_name = "autosd-qemu-package",
    image_hostname = "localhost",
    image_selinux_mode = "enforcing",
    content_rpms = [
        "openssh-server",
        "sudo",
    ],
)

aib_build(
    name = "image",
    builder = ":builder",
    manifest = ":manifest",
)
```

Build the image with:

```shell
bazel build //path/to/package:image
```

For the default `qemu` target on `x86_64`, the output file is named like
`image.x86_64.qcow2`. Output architecture comes from the Bazel
target platform. The extension is `qcow2` for `qemu`, `abootqemu`, and
`abootqemukvm`; `vhd` for `azure`; and `raw` for other AIB targets.

## Rules

### `aib_build_builder`

`aib_build_builder` builds an OCI archive containing the tools needed to build
AutoSD images. The resulting target also carries the AIB executable and distro
settings consumed by `aib_build`.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | Bazel target name | required | Names the Bazel target. Also used as the output image name when `image_name` is unset. |
| `aib` | string | `"aib"` | AIB executable path or command name. Use this when AIB is not available as `aib` on `PATH`. |
| `distro` | string | `"autosd10-sig"` | OS distribution name passed to AIB when building both the builder and final image. |
| `image_name` | string | `name` | Name of the generated builder OCI archive, without the `.tar` suffix. |

### `aib_manifest`

`aib_manifest` generates one `<name>.aib.yml` file. It owns all attributes that
control manifest content and carries any files in `srcs` forward to an
`aib_build` target that consumes it.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | Bazel target name | required | Names the target and the generated `<name>.aib.yml` file. Also supplies the top-level manifest `name` when `image_name` is unset. |
| `srcs` | list of labels | `[]` | Source or generated files referenced with `$(location)` in manifest attributes. These are forwarded as inputs to consuming image builds. |
| `image_name` | string | `name` | Top-level manifest `name`. |
| `image_version` | string | unset | Top-level manifest `version`; used by AIB as the OS version in the ostree commit and as `IMAGE_VERSION` in `/etc/build-info`. |
| `content_*` | strings, lists, dicts | unset | Root filesystem content: packages, repositories, files, links, systemd service state, container images, and SBOM path. |
| `qm_*` | strings, lists, dicts | unset | QM partition content and resource controls, including memory limits, CPU weight, and optional container checksum. |
| `image_*` | strings, lists, dicts | unset | Image-level settings: hostname, image size, SELinux, ostree ref, sealing, memory protection, partitions, and boot checks. |
| `network_*` | strings, lists, bools | unset | Dynamic or static network configuration. `network_dynamic` cannot be combined with `network_static_*` parameters. |
| `auth_*` | strings, lists, dicts | unset | Root credentials, root SSH keys, users, groups, and sshd settings. |
| `kernel_*` | strings, lists, bools, int | unset, except `kernel_loglevel = -1` | Kernel command line, debug logging, kernel package/version override, log level, and removed modules. |

### `aib_build`

`aib_build` loads the builder OCI archive produced by `aib_build_builder` and
invokes AIB with a manifest. The manifest may be a checked-in file, another
rule's single-file output, or an `aib_manifest` target.

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `name` | Bazel target name | required | Names the target and the output image basename. |
| `builder` | label | required | Label of an `aib_build_builder` target. This supplies the builder OCI archive, distro, and AIB executable. |
| `manifest` | label | required | A single manifest file or an `aib_manifest` target. |
| `target` | string | `"qemu"` | AIB target board or environment, such as `qemu` or `azure`. Also determines the output file extension. |

To build from a checked-in manifest, pass the file label directly:

```python
aib_build(
    name = "image",
    builder = ":builder",
    manifest = "image.aib.yml",
)
```

The detailed manifest parameter reference, including value types, nested
manifest mapping, validation rules, and examples, is in
[README.manifest.md](README.manifest.md).

Generated files can be included by listing them in `aib_manifest`'s `srcs` and
using a `$(location)` reference in an attribute such as `content_add_files` or
`qm_content_add_files`. See the manifest reference for a complete example.

## Manifest Attribute Convention

Most manifest attributes are named by flattening the YAML path with
underscores. For example:

```yaml
image:
  partitions:
    var:
      size: 4 GiB
```

is configured as:

```python
aib_manifest(
    name = "manifest",
    image_partitions_var_size = "4 GiB",
)
```

Most manifest booleans are string attributes using `"true"` or `"false"` so
that an omitted value stays distinct from an explicit false value. List values
use Bazel lists, simple maps use dictionaries, and object lists use dictionaries
whose values are `key=value` strings. See [README.manifest.md](README.manifest.md)
for examples of each shape.

## Example

```python
load("@rules_aib//:defs.bzl", "aib_build", "aib_build_builder", "aib_manifest")

aib_build_builder(
    name = "builder",
    image_name = "autosd-builder",
    distro = "autosd10-sig",
)

aib_manifest(
    name = "manifest",
    image_name = "autosd-qemu-package",
    image_version = "1.0.0",

    image_hostname = "localhost",
    image_image_size = "16 GiB",
    image_selinux_mode = "enforcing",
    image_partitions_var_size = "4 GiB",

    network_dynamic = True,

    content_rpms = ["sudo", "openssh-server"],
    content_systemd_enabled_services = ["sshd.service"],

    auth_root_password = "null",
    auth_root_ssh_keys = ["ssh-ed25519 AAAA... user@example"],

    kernel_cmdline = ["console=ttyS0"],
)

aib_build(
    name = "image",
    builder = ":builder",
    manifest = ":manifest",
    target = "qemu",
)
```

[aib-docs]: https://sigs.centos.org/automotive/latest/getting-started/about-automotive-image-builder.html
