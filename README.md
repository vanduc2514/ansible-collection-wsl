# Ansible Collection - vanduc2514.wsl_automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

The `vanduc2514.wsl_automation` collection provides Ansible modules and roles for managing Windows Subsystem for Linux (WSL) environments. It uses PowerShell modules to execute WSL commands, enabling automation of WSL distribution management and configuration.

## System Requirements

| Requirement | Details |
|------------|---------|
| Operating System | Windows 10 (version 1903+) or Windows 11 |
| WSL Feature | The WSL Windows feature (automatically enabled by this collection) |
| Hardware | Standard hardware capable of running Windows 10/11 |

## Ansible Requirements

The following Ansible components are required:

- ansible-core >= 2.15.0
- ansible-galaxy

All other dependencies will be resolved automatically during installation of the collection.

## Roles

The following roles provide essential functionality for WSL environment management:

### wsl

Configures the WSL system environment:

```yaml
- role: vanduc2514.wsl_automation.wsl
  vars:
    wsl_config_memory: 4GB
    wsl_config_processors: 4
```

This role handles WSL2 kernel installation, Windows feature configuration, and system-wide WSL parameters to establish the foundation for WSL distributions.

[Role documentation](roles/wsl/README.md)

### wsl_distribution

Manages WSL distribution lifecycle:

```yaml
- role: vanduc2514.wsl_automation.wsl_distribution
  vars:
    wsl_distribution_name: Ubuntu-22.04
    wsl_distribution_config_user_default: "wsl_admin"
```

This role provides comprehensive distribution management capabilities, including installation, configuration, user account provisioning, and background process configuration.

[Role Documentation](roles/wsl_distribution/README.md)

### wsl_sshd

Implements secure SSH access for WSL distributions:

This role configures OpenSSH Server in specified WSL distributions with options for local access configuration and controlled remote connectivity. Implementation follows security best practices with configurable authentication parameters.

#### Secure Local Access

This configuration implements a security-focused approach that limits SSH access through the Windows host as a secure jump server:

```yaml
- role: vanduc2514.wsl_automation.wsl_sshd
  vars:
    wsl_sshd_distribution_name: Ubuntu-22.04
    wsl_sshd_port: 2222
    # port_forward is disabled by default
```

Connection is established through the Windows host:
```bash
ssh -J windows_host wsl_user@localhost -p 2222
```

#### External Access Configuration

⚠️ **WARNING**: External access configuration requires careful security implementation. The following parameters provide a starting point for secure configuration but should be supplemented with appropriate network security measures.

1. Initial distribution security configuration:

```yaml
- role: vanduc2514.wsl_automation.wsl_distribution
  vars:
    wsl_distribution_name: Ubuntu-22.04
    wsl_distribution_config_user_default: "wsl_admin"
    wsl_distribution_config_user_default_password: "{{ vault_secure_password }}"
    wsl_distribution_config_user_default_authorized_keys:
      - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

2. SSH server hardening with security parameters:

```yaml
- role: vanduc2514.wsl_automation.wsl_sshd
  vars:
    wsl_sshd_distribution_name: Ubuntu-22.04
    wsl_sshd_port: 2222
    wsl_sshd_port_forward_enabled: true
    # The port to forward in your router
    wsl_sshd_port_forward_host_port: 3322
    wsl_sshd_password_authentication: false
    wsl_sshd_permit_root_login: false
    wsl_sshd_extra_configs:
      MaxAuthTries: 3
      ClientAliveInterval: 300
      PermitEmptyPasswords: false
      LoginGraceTime: 60
```

3. Additional security measures to consider:
   - Network firewall configuration
   - Port forwarding security
   - Host-based intrusion detection
   - Security monitoring implementation
   - System update procedures
   - Authentication failure monitoring (e.g., fail2ban)
   - DDoS mitigation strategy

When security requirements are stringent, the **Secure Local Access** configuration is recommended.

[Role Documentation](roles/wsl_sshd/README.md)

## Modules

For granular control, the collection provides module-level access to WSL functionality:

| Module | Functionality |
|--------|--------------|
| wsl_instance | Distribution lifecycle management |
| wsl_file | File system operations within WSL |
| wsl_package | Cross-distribution package management |
| wsl_user | Basic User account administration |
| wsl_systemd | Service management for systemd enabled distributions |
| wsl_sysvinit | Service management for systemd disabled distributions |
| wsl_slurp | Content retrieval with base64 encoding |

## Install from ansible-galaxy

Run the following command line

```bash
ansible-galaxy collection install vanduc2514.wsl_automation
```

or define it in `requirements.yml`

```yml
collections:
  - name: vanduc2514.wsl_automation
```

## Install from git

Run the following command line

```bash
ansible-galaxy collection install git+https://github.com/vanduc2514/ansible-collection-wsl-automation.git
```

or define it in `requirements.yml`

```yml
collections:
  - name: vanduc2514.wsl_automation
    source: https://github.com/vanduc2514/ansible-collection-wsl-automation.git
    type: git
```

## Example Minimum Playbook

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl
    - role: vanduc2514.wsl_automation.wsl_distribution
    - role: vanduc2514.wsl_automation.wsl_sshd
```

### Example Recommend Playbook

Store sensitive values such as passwords in an Ansible vault file.

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl
      vars:
        wsl_config_memory: 4GB
        wsl_config_processors: 4
        wsl_config_swap: 2GB
        wsl_config_swap_file: "D:\\wsl\\swap.vhdx"

    - role: vanduc2514.wsl_automation.wsl_distribution
      vars:
        wsl_distribution_name: Ubuntu-22.04
        wsl_distribution_config_user_default: "wsl_admin"
        wsl_distribution_config_user_default_password: "{{ vault_wsl_user_password }}"
        wsl_distribution_config_user_default_authorized_keys:
          - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"

    - role: vanduc2514.wsl_automation.wsl_sshd
      vars:
        wsl_sshd_distribution_name: Ubuntu-22.04
        wsl_sshd_port: 2222
        wsl_sshd_password_authentication: false
        wsl_sshd_permit_root_login: false
        wsl_sshd_port_forward_enabled: false
```

## Additional Resources

For further readings:
- [Ansible Documentation](https://docs.ansible.com)
- [Windows Subsystem for Linux Documentation](https://docs.microsoft.com/en-us/windows/wsl/)

## License

MIT

## Author

Developed by [Duc Nguyen (@vanduc2514)](https://github.com/vanduc2514)
