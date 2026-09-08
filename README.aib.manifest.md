# AIB Manifest Parameter Reference

This document describes the Automotive Image Builder manifest settings exposed
through the `aib_manifest()` rule. For the library overview and rule-level
reference, see [README.md](README.md).

The generated manifest is built from rule parameters. In general, manifest
paths are flattened with underscores:

```yaml
image:
  hostname: localhost
  partitions:
    var:
      size: 4 GiB
```

becomes:

```python
aib_manifest(
    name = "manifest",
    image_hostname = "localhost",
    image_partitions_var_size = "4 GiB",
)
```

Top-level `name` comes from `image_name` or the `aib_manifest` target name.
Top-level `version` comes from `image_version`.

## Value Types

Use normal Bazel string values for scalar manifest strings:

```python
image_hostname = "localhost"
image_image_size = "16 GiB"
image_selinux_mode = "enforcing"
```

Most manifest booleans are string parameters with values `"true"` or `"false"`:

```python
image_sealed = "false"
image_partitions_root_grow = "true"
auth_sshd_config_password_authentication = "false"
```

This keeps "not set" distinct from an explicit `false`. `network_dynamic` is a
regular Bazel boolean because it selects an empty object:

```python
network_dynamic = True
```

List properties use `attr.string_list`:

```python
content_rpms = ["sudo", "openssh-server"]
kernel_cmdline = ["console=ttyS0", "quiet"]
```

Simple maps use `attr.string_dict`:

```python
image_selinux_booleans = {
    "httpd_can_network_connect": "true",
}
content_add_symlinks = {
    "/usr/local/bin/tool": "/opt/tool/bin/tool",
}
```

Object lists use `attr.string_list_dict`. The dictionary key is the object's
required identity field, and the value is a list of `key=value` strings:

```python
content_repos = {
    "custom": [
        "baseurl=https://example.com/repo",
        "priority=20",
    ],
}
```

## Parameter Reference

### Top-Level And Supporting Parameters

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `image_name` | `name` | Manifest name. Defaults to the `aib_manifest` target name. |
| `image_version` | `version` | Manifest version. AIB uses this as the OS version in the ostree commit and exposes it as `IMAGE_VERSION` in `/etc/build-info`. |
| `srcs` | not rendered into manifest | Source or generated file labels referenced with `$(location)` in manifest parameters; forwards them as inputs to an `aib_build` target that consumes this manifest. |

### Content And QM Content Parameters

The `content_*` parameters render under `content`. The `qm_content_*`
parameters render under `qm.content` with the same field names and value shapes.

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `content_rpms`, `qm_content_rpms` | `rpms` | RPM package names to install. |
| `content_enable_repos`, `qm_content_enable_repos` | `enable_repos` | Predefined distribution repository names to enable, such as `debug` or `devel`. |
| `content_repos`, `qm_content_repos` | `repos` | Extra DNF repositories keyed by repo id. |
| `content_container_images`, `qm_content_container_images` | `container_images` | Container images to embed, keyed by source image. |
| `content_add_files`, `qm_content_add_files` | `add_files` | Files to add, keyed by destination path. Supports `$(location)` expansion for labels listed in `srcs`. |
| `content_chmod_files`, `qm_content_chmod_files` | `chmod_files` | File mode changes, keyed by path. |
| `content_chown_files`, `qm_content_chown_files` | `chown_files` | File owner or group changes, keyed by path. |
| `content_remove_files`, `qm_content_remove_files` | `remove_files` | Installed file paths to remove. |
| `content_make_dirs`, `qm_content_make_dirs` | `make_dirs` | Directories to create, keyed by path. |
| `content_add_symlinks`, `qm_content_add_symlinks` | `add_symlinks` | Symlinks to create, keyed by link path with target values. |
| `content_systemd_enabled_services`, `qm_content_systemd_enabled_services` | `systemd.enabled_services` | Systemd services to enable. |
| `content_systemd_disabled_services`, `qm_content_systemd_disabled_services` | `systemd.disabled_services` | Systemd services to disable. |
| `content_systemd_masked_services`, `qm_content_systemd_masked_services` | `systemd.masked_services` | Systemd services to mask. |
| `content_sbom_doc_path`, `qm_content_sbom_doc_path` | `sbom.doc_path` | Output path for the generated SPDX SBOM document. |

Object-list parameter fields:

| Parameter | Key | Supported `key=value` entries |
| --- | --- | --- |
| `*_repos` | repo id | One of `baseurl`, `metalink`, or `mirrorlist` is required. Optional `priority` must be an integer. |
| `*_container_images` | source image | `tag`, `digest`, `name`, `containers-transport`, `index`. `containers-transport` must be `docker` or `containers-storage`; `index` is a boolean string. |
| `*_add_files` | destination path | Exactly one of `source_path`, `url`, `text`, or `source_glob`; optional `preserve_path`, `allow_empty`, and integer `max_files`. |
| `*_chmod_files` | path | Required `mode`; optional boolean string `recursive`. |
| `*_chown_files` | path | At least one of `user` or `group`; optional boolean string `recursive`. |
| `*_make_dirs` | path | Optional `mode`, `parents`, and `exist_ok`. `parents` and `exist_ok` are boolean strings. |

### QM Parameters

These parameters render under `qm` outside of `qm.content`.

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `qm_memory_limit_max` | `memory_limit.max` | `MemoryMax` for the QM partition. |
| `qm_memory_limit_high` | `memory_limit.high` | `MemoryHigh` for the QM partition. |
| `qm_cpu_weight` | `cpu_weight` | `CPUWeight` for the QM partition. Must be `idle` or an integer from `1` to `10000`. |
| `qm_container_checksum` | `container_checksum` | Optional container digest validated at boot. |

### Image Parameters

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `image_image_size` | `image.image_size` | Total output image size, with a suffix such as `GB`, `GiB`, or `MiB`. |
| `image_sealed` | `image.sealed` | Boolean string that configures sealed-image behavior. The AIB manifest default is true. |
| `image_enable_oom_protection` | `image.enable_oom_protection` | Boolean string that configures OOM killer protection. |
| `image_enable_reclaim_protection` | `image.enable_reclaim_protection` | Boolean string that configures reclaim protection on system and user slices. |
| `image_cg_memory_min` | `image.cg_memory_min` | Minimum memory value for system and user slices when reclaim protection is enabled. |
| `image_hostname` | `image.hostname` | Hostname to configure in the generated image. |
| `image_selinux_mode` | `image.selinux_mode` | SELinux mode to configure. |
| `image_selinux_policy` | `image.selinux_policy` | SELinux policy name. |
| `image_selinux_booleans` | `image.selinux_booleans` | SELinux booleans keyed by boolean name. Values are boolean strings. |
| `image_ostree_ref` | `image.ostree_ref` | Ostree ref name to use for the image. |
| `image_boot_checks_commands` | `image.boot_checks.commands` | Boot-check commands keyed by unique check name. Values are command lines. |
| `image_boot_checks_systemd` | `image.boot_checks.systemd` | Systemd units used to verify a successful boot. |

Partition parameters:

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `image_partitions_root_grow` | `image.partitions.root.grow` | Boolean string that configures root filesystem growth to the physical image size. |
| `image_partitions_aboot_size` | `image.partitions.aboot.size` | Size of the `aboot` partition. |
| `image_partitions_ukiboot_size` | `image.partitions.ukiboot.size` | Size of the `ukiboot` partition. |
| `image_partitions_boot_size` | `image.partitions.boot.size` | Size of the `boot` partition. |
| `image_partitions_efi_size` | `image.partitions.efi.size` | Size of the `efi` partition. |
| `image_partitions_vbmeta_size` | `image.partitions.vbmeta.size` | Size of the `vbmeta` partition. |
| `image_partitions_sbl_size` | `image.partitions.sbl.size` | Size of the `sbl` partition. |
| `image_partitions_var_size` | `image.partitions.var.size` | Fixed size of `/var`. Mutually exclusive with `image_partitions_var_relative_size` and `image_partitions_var_external`. |
| `image_partitions_var_relative_size` | `image.partitions.var.relative_size` | `/var` size relative to total image size. Mutually exclusive with `image_partitions_var_size` and `image_partitions_var_external`. |
| `image_partitions_var_external` | `image.partitions.var.external` | Boolean string that places `/var` on an external device. Mutually exclusive with `image_partitions_var_size` and `image_partitions_var_relative_size`. |
| `image_partitions_var_uuid` | `image.partitions.var.uuid` | UUID of the `/var` partition. |
| `image_partitions_var_qm_size` | `image.partitions.var_qm.size` | Fixed size of `/var/qm`. Mutually exclusive with `image_partitions_var_qm_relative_size` and `image_partitions_var_qm_external`. |
| `image_partitions_var_qm_relative_size` | `image.partitions.var_qm.relative_size` | `/var/qm` size relative to total image size. Mutually exclusive with `image_partitions_var_qm_size` and `image_partitions_var_qm_external`. |
| `image_partitions_var_qm_external` | `image.partitions.var_qm.external` | Boolean string that places `/var/qm` on an external device. Mutually exclusive with `image_partitions_var_qm_size` and `image_partitions_var_qm_relative_size`. |
| `image_partitions_var_qm_uuid` | `image.partitions.var_qm.uuid` | UUID of the `/var/qm` partition. |

### Network Parameters

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `network_dynamic` | `network.dynamic` | Enables NetworkManager dynamic network setup. Cannot be set with `network_static_*` parameters. |
| `network_static_ip` | `network.static.ip` | Fixed IP address to assign. |
| `network_static_ip_prefixlen` | `network.static.ip_prefixlen` | CIDR prefix length for the static IP. The default sentinel, `-1`, omits the field. |
| `network_static_gateway` | `network.static.gateway` | Default gateway IP address. |
| `network_static_dns` | `network.static.dns` | DNS server IP address. |
| `network_static_iface` | `network.static.iface` | Network interface name to configure. |
| `network_static_iface_early` | `network.static.iface_early` | Network interface name during early boot. |
| `network_static_load_module` | `network.static.load_module` | Kernel module names to load at boot for network support. |

### Auth Parameters

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `auth_root_password` | `auth.root_password` | Root encrypted password as returned by `crypt(3)`. Use the literal string `"null"` to render YAML `null`. |
| `auth_root_ssh_keys` | `auth.root_ssh_keys` | Root SSH public keys to add to `authorized_keys`. |
| `auth_sshd_config_password_authentication` | `auth.sshd_config.PasswordAuthentication` | Boolean string for sshd `PasswordAuthentication`. |
| `auth_sshd_config_permit_root_login` | `auth.sshd_config.PermitRootLogin` | `true`, `false`, `prohibit-password`, or `forced-commands-only` for sshd `PermitRootLogin`. |
| `auth_users` | `auth.users` | Users to create, keyed by username. |
| `auth_groups` | `auth.groups` | Groups to create, keyed by group name. |

Object-list parameter fields:

| Parameter | Key | Supported `key=value` entries |
| --- | --- | --- |
| `auth_users` | username | `gid`, `uid`, `groups`, `description`, `home`, `shell`, `password`, `key`, `keys`, `expiredate`, `force_password_reset`. `gid`, `uid`, and `expiredate` must be integers; `force_password_reset` is a boolean string. `groups` accepts comma-separated values and may be repeated; `keys` may be repeated. |
| `auth_groups` | group name | Optional integer `gid`. An empty value list renders an empty group object. |

### Kernel Parameters

| Parameter | Manifest field | Purpose |
| --- | --- | --- |
| `kernel_debug_logging` | `kernel.debug_logging` | Adds more kernel debug logging. This is a Bazel boolean, not a string boolean. |
| `kernel_cmdline` | `kernel.cmdline` | Extra kernel command-line options. |
| `kernel_kernel_package` | `kernel.kernel_package` | Custom kernel package name instead of `kernel-automotive`. |
| `kernel_kernel_version` | `kernel.kernel_version` | Custom kernel package version. |
| `kernel_loglevel` | `kernel.loglevel` | Kernel log level. The default sentinel, `-1`, omits the field. |
| `kernel_remove_modules` | `kernel.remove_modules` | Kernel modules and dependencies to remove from the image. |

## Content And QM Content

`content_*` parameters render the manifest `content` object. `qm_content_*`
parameters render `qm.content` with the same shape.

Packages and repositories:

```python
content_enable_repos = ["debug"]
content_rpms = ["sudo", "tar"]
content_repos = {
    "local": ["baseurl=file:///repo", "priority=10"],
}
```

Container images:

```python
content_container_images = {
    "quay.io/fedora/fedora": [
        "tag=latest",
        "name=fedora",
        "index=true",
    ],
}
```

Files, ownership, directories, and links:

```python
content_add_files = {
    "/etc/example.conf": ["source_path=config/example.conf"],
    "/etc/motd": ["text=Built by Bazel"],
}
content_chmod_files = {
    "/usr/local/bin/tool": ["mode=0755"],
}
content_chown_files = {
    "/var/lib/app": ["user=app", "group=app", "recursive=true"],
}
content_make_dirs = {
    "/var/lib/app": ["mode=0755", "parents=true"],
}
content_remove_files = ["/etc/unwanted.conf"]
content_add_symlinks = {
    "/usr/local/bin/tool": "/opt/tool/bin/tool",
}
```

To add a file generated by another Bazel rule, declare its target in `srcs`
and use `$(location)` as the `source_path`. Bazel then builds the file first,
expands its path relative to the generated manifest, and makes it available to
the image-build action:

```python
genrule(
    name = "generated_config",
    outs = ["generated.conf"],
    cmd = "echo 'MESSAGE=\"Generated by Bazel\"' > $@",
)

aib_manifest(
    name = "manifest",
    srcs = [":generated_config"],
    content_add_files = {
        "/etc/generated.conf": [
            "source_path=$(location :generated_config)",
        ],
    },
)
```

The same `srcs` attribute supplies labels referenced by
`qm_content_add_files` and future manifest parameters. A label used with
`$(location)` must produce exactly one file. List each generated target
separately when adding multiple files.

Systemd and SBOM:

```python
content_systemd_enabled_services = ["sshd.service"]
content_systemd_disabled_services = ["debug-shell.service"]
content_systemd_masked_services = ["ctrl-alt-del.target"]
content_sbom_doc_path = "/usr/share/sbom/content.spdx.json"
```

QM-specific properties:

```python
qm_content_rpms = ["openssh-server"]
qm_memory_limit_max = "2G"
qm_memory_limit_high = "1500M"
qm_cpu_weight = "100"
qm_container_checksum = "sha256:..."
```

`qm_cpu_weight` is either `"idle"` or an integer from `1` to `10000`.

## Image

Common image fields:

```python
image_hostname = "localhost"
image_image_size = "16 GiB"
image_selinux_mode = "enforcing"
image_selinux_policy = "targeted"
image_ostree_ref = "autosd/x86_64/qemu-image"
image_sealed = "false"
```

SELinux booleans:

```python
image_selinux_booleans = {
    "virt_use_nfs": "true",
}
```

Partitions:

```python
image_partitions_root_grow = "true"
image_partitions_boot_size = "512 MiB"
image_partitions_var_size = "4 GiB"
image_partitions_var_uuid = "9c6ae55b-cf88-45b8-84e8-64990759f39d"
image_partitions_var_qm_relative_size = "0.2"
```

For `var` and `var_qm`, `relative_size`, `size`, and `external` are mutually
exclusive.

Boot checks:

```python
image_boot_checks_commands = {
    "network": "nm-online -q",
}
image_boot_checks_systemd = ["sshd.service", "multi-user.target"]
```

## Network

Use dynamic networking:

```python
network_dynamic = True
```

Or static networking:

```python
network_static_ip = "192.0.2.10"
network_static_ip_prefixlen = 24
network_static_gateway = "192.0.2.1"
network_static_dns = "192.0.2.53"
network_static_iface = "eth0"
network_static_load_module = ["e1000e"]
```

Do not combine `network_dynamic` with `network_static_*` parameters.

## Auth

Root login:

```python
auth_root_password = "null"
auth_root_ssh_keys = [
    "ssh-ed25519 AAAA... user@example",
]
```

Use the literal string `"null"` to render YAML `null` for `root_password`.

SSHD configuration:

```python
auth_sshd_config_password_authentication = "false"
auth_sshd_config_permit_root_login = "prohibit-password"
```

`auth_sshd_config_permit_root_login` accepts `"true"`, `"false"`,
`"prohibit-password"`, or `"forced-commands-only"`.

Users and groups:

```python
auth_groups = {
    "app": ["gid=1001"],
}
auth_users = {
    "app": [
        "uid=1001",
        "gid=1001",
        "groups=wheel,systemd-journal",
        "home=/var/lib/app",
        "shell=/usr/sbin/nologin",
        "keys=ssh-ed25519 AAAA... app@example",
        "force_password_reset=false",
    ],
}
```

Repeat `groups=...` or `keys=...` entries when a single comma-separated value is
not convenient.

## Kernel

```python
kernel_debug_logging = True
kernel_cmdline = ["console=ttyS0", "quiet"]
kernel_kernel_package = "kernel-automotive"
kernel_kernel_version = "1.2.3"
kernel_loglevel = 4
kernel_remove_modules = ["floppy"]
```

`kernel_loglevel = -1` is the default sentinel and omits the manifest field.

## Complete Example

```python
load("@os_autosd//toolchain/aib:defs.bzl", "aib_build", "aib_build_builder", "aib_manifest")

aib_build_builder(
    name = "builder",
    image_name = "autosd-builder",
)

aib_manifest(
    name = "manifest",
    image_name = "autosd-qemu-package",
    image_version = "1.0.0",

    image_hostname = "localhost",
    image_image_size = "16 GiB",
    image_selinux_mode = "enforcing",
    image_partitions_var_size = "4 GiB",

    network_static_ip = "192.0.2.10",
    network_static_ip_prefixlen = 24,
    network_static_gateway = "192.0.2.1",
    network_static_dns = "192.0.2.53",

    content_rpms = ["sudo", "openssh-server"],
    content_repos = {
        "custom": ["baseurl=https://example.com/repo", "priority=20"],
    },
    content_add_files = {
        "/etc/motd": ["text=Built by Bazel"],
    },
    content_systemd_enabled_services = ["sshd.service"],

    auth_root_password = "null",
    auth_root_ssh_keys = ["ssh-ed25519 AAAA... user@example"],

    kernel_cmdline = ["console=ttyS0"],
)

aib_build(
    name = "image",
    builder = ":builder",
    manifest = ":manifest",
)
```
