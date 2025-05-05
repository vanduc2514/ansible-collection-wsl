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

### Port Forwarding Configuration

Setting these variables allows connecting to wsl distribution via ssh from LAN network

| Configuration Option | Description | Default |
|---------------------|-------------|---------|
| `wsl_sshd_port_forward_enabled` | Enable port forwarding from Windows to WSL | `false` |
| `wsl_sshd_port_forward_windows_port` | Windows port to forward | `{{ wsl_sshd_port }}` |
| `wsl_sshd_port_forward_wsl_port` | WSL port to forward to | `{{ wsl_sshd_port }}` |

## Example Playbook

Start sshd with systemd

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_sshd
      vars:
        wsl_sshd_distribution_name: Ubuntu-22.04
```

Setup with port forwarding

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_sshd
      vars:
        wsl_sshd_distribution_name: Ubuntu-22.04
        wsl_sshd_port: 2220
        wsl_sshd_port_forward_enabled: true
        wsl_sshd_port_forward_windows_port: 3320
```

## License

MIT

## Author Information

Duc Nguyen (@vanduc2514)