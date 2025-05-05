# Ansible Role: wsl_distribution

This role manages Windows Subsystem for Linux (WSL) distributions on Windows hosts.

## Requirements

- Windows 10 version 1903 or higher, or Windows 11
- WSL feature must be installed and enabled

## Role Variables

### Basic Configuration

These variables control the core behavior of the WSL distribution, including its name, version, and operational state.

| Configuration Option | Description | Default |
|---------------------|-------------|---------|
| `wsl_distribution_name` | Distribution name (required). If rootfs is not provided, install the distribution from online distribution | - |
| `wsl_distribution_arch_version` | WSL architecture version to use (1 or 2) | `2` |
| `wsl_distribution_state` | Desired state of the distribution (run, stop, absent) | `run` |

### Installation Settings

These variables determine how the WSL distribution is installed, whether from the Microsoft Store, a custom rootfs, or other sources.

| Configuration Option | Description | Default |
|---------------------|-------------|---------|
| `wsl_distribution_install_web_download` | Whether to download distribution from the Microsoft Store | `true` |
| `wsl_distribution_import_rootfs_path` | Local path to the rootfs tarball for custom distribution import | - |
| `wsl_distribution_import_rootfs_download_path` | URL to import rootfs tarball. If the path is an external source, attempt to download it first. If the path is an AppX bundle or a zip file, set `wsl_distribution_import_bundle` to `true` | - |
| `wsl_distribution_import_rootfs_download_checksum` | Checksum value for verifying downloaded rootfs integrity | - |
| `wsl_distribution_import_rootfs_download_checksum_algorithm` | Algorithm used for checksum verification | `sha256` |
| `wsl_distribution_import_dir_path` | Target directory path where the distribution will be imported | default to `$env:ProgramData\WSLDistributions` |
| `wsl_distribution_import_bundle` | Whether to import distribution from an AppX bundle or a zip file | `false` |
| `wsl_distribution_import_vhd` | Whether to import distribution as a Virtual Hard Disk | `false` |

### WSL Configuration

The role uses the following configuration structure. For detailed information about these settings, refer to the [Official Microsoft WSL Configuration Documentation](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

| Configuration Option | Description | Default |
|----------------------|-------------|---------|
| `wsl_distribution_config_boot_command` | Command to run on WSL startup | - |
| `wsl_distribution_config_boot_systemd` | Enable systemd support | `true` |
| `wsl_distribution_config_automount_enabled` | Enable automatic mounting of Windows drives | `true` |
| `wsl_distribution_config_automount_mountFsTab` | Enable mounting via /etc/fstab | - |
| `wsl_distribution_config_automount_root` | Root directory for Windows drive mounts | `/mnt/` |
| `wsl_distribution_config_automount_options` | Mount options for Windows drives, comma separted value | - |
| `wsl_distribution_config_network_hostname` | Set WSL distribution hostname | - |
| `wsl_distribution_config_network_generateHosts` | Enable automatic /etc/hosts generation | `true` |
| `wsl_distribution_config_network_generateResolvConf` | Enable automatic /etc/resolv.conf generation | `true` |
| `wsl_distribution_config_interop_enabled` | Enable Windows process interoperability | `true` |
| `wsl_distribution_config_interop_appendWindowsPath` | Add Windows PATH to $PATH | `true` |
| `wsl_distribution_config_user_default` | Default user for WSL distribution | `root` |

### Additional Configuration for default user

These variables control the creation and configuration of the default user in the WSL distribution.

| Configuration Option | Description | Default |
|----------------------|-------------|---------|
| `wsl_distribution_config_user_default_uid` | UID for the default user | - |
| `wsl_distribution_config_user_default_home_path` | Home directory for the default user | Default to `/home/user` |
| `wsl_distribution_config_user_default_login_shell` | Login shell for the default user | `/bin/sh` |
| `wsl_distribution_config_user_default_sudo` | Whether to grant sudo privileges to the default user | `false` |
| `wsl_distribution_config_user_default_password` | Password for the default user in plain text. Set this value will reset user password for every run | - |
| `wsl_distribution_config_user_default_authorized_keys` | List of SSH public keys to add to authorized_keys for the default user | `[]` |

### Extra WSL Configuration

`wsl_distribution_extra_configs`: Additional configuration sections and properties to append to wsl.conf

Example:
```yaml
wsl_distribution_extra_configs:
  custom_section:
    property1: value1
    property2: value2
  another_section:
    setting1: true
    setting2: "string value"
```

This will generate:
```ini
[custom_section]
property1 = value1
property2 = value2

[another_section]
setting1 = true
setting2 = string value
```

## Example Playbook

Install from online distribution

```yaml
- name: Install WSL Distribution
  hosts: windows
  roles:
    - role: vanduc2514.wsl_automation_wsl_distribution
      vars:
        wsl_distribution_name: Ubuntu
        wsl_distribution_config_boot_systemd: true
        wsl_distribution_config_user_default: "myuser"
```

Import from external source

```yaml
- name: Import WSL Distribution from external source
  hosts: windows
    - role: wsl_distribution
      vars:
        wsl_distribution_name: AlmaLinux-9.3.0.0
        wsl_distribution_import_rootfs_path: "https://wsl.almalinux.org/9/AlmaLinuxOS-9_9.3.0.0_x64.appx"
        wsl_distribution_import_rootfs_download_checksum: dce304363673c5c3eeac1bb4cb960489ff61ff7fbb11873311d42b1ee0eb4055
        wsl_distribution_import_rootfs_download_checksum_algorithm: sha256
        wsl_distribution_import_bundle: true
        wsl_distribution_import_dir_path: D:\\WSL\\CustomLinux
        wsl_distribution_config_boot_systemd: true
        wsl_distribution_config_user_default: "myuser"
        wsl_distribution_state: run
```

Import from local `tar` ball

```yaml
- name: Import WSL Distribution from local tar file
  hosts: windows
    - role: wsl_distribution
      vars:
        wsl_distribution_name: CustomLinux
        wsl_distribution_import_rootfs_path: "C:\\Downloads\\CustomLinux.tar"
        wsl_distribution_import_dir_path: D:\\WSL\\CustomLinux
        wsl_distribution_config_boot_systemd: true
        wsl_distribution_config_user_default: "myuser"
        wsl_distribution_state: run
```

Create a distribution with a custom default user

```yaml
- name: Install WSL Distribution with custom default user
  hosts: windows
  roles:
    - role: vanduc2514.wsl_automation_wsl_distribution
      vars:
        wsl_distribution_name: Ubuntu
        wsl_distribution_config_boot_systemd: true
        wsl_distribution_config_user_default_name: "wsluser"
        wsl_distribution_config_user_default_uid: 1000
        wsl_distribution_config_user_default_home_path: "/home/wsluser"
        wsl_distribution_config_user_default_login_shell: "/bin/bash"
        wsl_distribution_config_user_default_sudo: true
        wsl_distribution_config_user_default_password: "secure_password"
```

Create a distribution with SSH authorized keys:

```yaml
- name: Install WSL Distribution with SSH authorized keys
  hosts: windows
  roles:
    - role: vanduc2514.wsl_automation_wsl_distribution
      vars:
        wsl_distribution_name: Ubuntu
        wsl_distribution_config_boot_systemd: true
        wsl_distribution_config_user_default: "wsluser"
        wsl_distribution_config_user_default_sudo: true
        wsl_distribution_config_user_default_authorized_keys:
          - "ssh-rsa AAAAB3NzaC1yc2EAAAADA... user@host"
          - "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```

## License

MIT

## Author Information

Duc Nguyen ([@vanduc2514](https://github.com/vanduc2514))
