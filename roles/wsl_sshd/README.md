# Ansible Role: wsl_sshd

This role configures and manages SSH daemon service in Windows Subsystem for Linux (WSL) distributions.

## Requirements

- Windows 10 version 1903 or higher, or Windows 11
- WSL feature must be installed and enabled
- WSL distribution must be installed

## Role Variables

### Basic Configuration

These variables control the core behavior of the SSH daemon service.

| Configuration Option | Description | Default |
|---------------------|-------------|---------|
| `wsl_sshd_distribution_name` | Name of the WSL distribution where sshd will be configured (required) | - |
| `wsl_sshd_service_name` | Name of the SSH daemon service | `ssh` |
| `wsl_sshd_service_type` | Type of service management to use (systemd or sysvinit) | `systemd` |
| `wsl_sshd_state` | Desired state of the SSH daemon service (started, stopped, absent) | `started` |
| `wsl_sshd_enabled` | Whether the SSHD service should start after the WSL distribution run | `true` |
| `wsl_sshd_dbus_timeout` | Timeout in seconds for waiting on dbus to be ready when using systemd | `120` |

### SSH Configuration

The role uses the following configuration structure. For detailed information about these settings, refer to the [sshd_config manual](https://linux.die.net/man/5/sshd_config).

**Note**: Boolean values in SSH configuration (including in `wsl_sshd_extra_configs`) are automatically converted to `yes` or `no` in the generated sshd_config file.


| Configuration Option | Description | Default |
|---------------------|-------------|---------|
| `wsl_sshd_port` | SSH daemon listening port | `2222` |
| `wsl_sshd_listen_address` | SSH daemon listening address | `0.0.0.0` |
| `wsl_sshd_permit_root_login` | Allow root login via SSH | `false` |
| `wsl_sshd_password_authentication` | Allow password authentication | `false` |
| `wsl_sshd_pubkey_authentication` | Allow public key authentication | `true` |

### Extra SSH Configuration

`wsl_sshd_extra_configs`: Additional configuration to append to sshd_config

Example:

```yaml
wsl_sshd_extra_configs:
  MaxAuthTries: "3"
  LoginGraceTime: "60"
```

This will generate:
```
MaxAuthTries 3
LoginGraceTime 60
```

## Example Playbook

Basic setup with defaults (started state)

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_sshd
      vars:
        wsl_sshd_distribution_name: Ubuntu-22.04
```

Stop SSH daemon

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_sshd
      vars:
        wsl_sshd_distribution_name: Ubuntu-22.04
        wsl_sshd_state: stopped
```

Remove SSH daemon and configuration

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_sshd
      vars:
        wsl_sshd_distribution_name: Ubuntu-22.04
        wsl_sshd_state: absent
```

## License

MIT

## Author Information

Duc Nguyen ([@vanduc2514](https://github.com/vanduc2514))