# Ansible Role: wsl_distribution

This role manages Windows Subsystem for Linux (WSL) distributions on Windows hosts.

## Requirements

- Windows 10 version 1903 or higher, or Windows 11
- WSL feature must be installed and enabled
- PowerShell

## Role Variables

```yaml
# Distribution name (required)
wsl_distribution_name: "Ubuntu"

# Installation settings
wsl_distribution_web_download: true
wsl_distribution_rootfs_path: ""
wsl_distribution_rootfs_download_path: ""
wsl_distribution_rootfs_download_checksum: ""
wsl_distribution_rootfs_download_checksum_algorithm: "sha256"
wsl_distribution_import_dir_path: ""
wsl_distribution_import_bundle: false
wsl_distribution_import_vhd: false

# Architecture version (1 or 2)
wsl_distribution_arch_version: 2

# Desired state (run, stop, absent)
wsl_distribution_state: "run"

# WSL configuration
wsl_distribution_config:
  boot:
    command: ""
    systemd: true
  automount:
    enabled: true
    root: "/mnt/"
    options: ""
  network:
    hostname: ""
    generateHosts: true
    generateResolvConf: true
  interop:
    enabled: true
    appendWindowsPath: true
  user:
    default: ""
```

## Example Playbook

```yaml
- hosts: windows
  tasks:
    - name: Install Ubuntu WSL
      include_role:
        name: wsl_distribution
      vars:
        wsl_distribution_name: "Ubuntu"
        wsl_distribution_config:
          boot:
            systemd: true
          user:
            default: "myuser"

    - name: Install custom distribution
      include_role:
        name: wsl_distribution
      vars:
        wsl_distribution_name: "CustomLinux"
        wsl_distribution_web_download: false
        wsl_distribution_rootfs_path: "path/to/custom.tar.gz"
        wsl_distribution_import_dir_path: "D:\\WSL\\CustomLinux"
        wsl_distribution_state: "run"
```

## License

MIT