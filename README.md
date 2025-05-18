# Ansible Collection - vanduc2514.wsl_automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

The `vanduc2514.wsl_automation` collection provides Ansible modules and roles for managing multiple Windows Subsystem for Linux (WSL) environments. Underlying, It uses PowerShell modules to execute WSL commands, enabling automation of WSL distribution management and configuration.

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

[Role documentation](roles/wsl/README.md)

### wsl_distribution

Manages WSL distributions including installation, basic user management and distribution configuration.

```yaml
- role: vanduc2514.wsl_automation.wsl_distribution
  vars:
    wsl_distribution_name: Ubuntu-22.04
    wsl_distribution_config_user_default: "wsl_admin"
```

[Role Documentation](roles/wsl_distribution/README.md)

### wsl_sshd

Install and Configure OpenSSH Server in WSL distribution

```yaml
- role: vanduc2514.wsl_automation.wsl_sshd
  vars:
    wsl_sshd_distribution_name: Ubuntu-22.04
    wsl_sshd_port: 2222
    wsl_sshd_password_authentication: false
    wsl_sshd_permit_root_login: false
```

After configuration, WSL Distribution can be access via SSH with Windows Jump Host
```bash
ssh -o ProxyCommand="ssh -W %h:%p windows_host" wsl_user@localhost -p 2222
```

[Role Documentation](roles/wsl_sshd/README.md)

### wsl_port_forward

Forward a port in WSL distribution to Windows, allow accessing through LAN

```yaml
- role: vanduc2514.wsl_automation.wsl_port_forward
  vars:
    wsl_port_forward_policy_name: WSL-Port-Forward
    wsl_port_forward_host_port: 8080
    wsl_port_forward_target_port: 80
```

[Role Documentation](roles/wsl_port_forward/README.md)

## Internet SSH Access Configuration

Enable remote SSH access from the internet with port forwarding.

⚠️ **WARNING**: Expose WSL distribution to the internet is dangerous and requires careful security configuration. The following parameters provide a starting point for secure configuration but should be supplemented with additional security harderning measures.

### Example configuration

1. Configure WSL Distribution with additional password and SSH authorized key (public key)

```yaml
- role: vanduc2514.wsl_automation.wsl_distribution
  vars:
    wsl_distribution_name: Ubuntu-22.04
    wsl_distribution_config_user_default: "wsl_admin"
    wsl_distribution_config_user_default_password: "{{ vault_secure_password }}"
    wsl_distribution_config_user_default_authorized_keys:
      - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

2. (Optional) Configure OpenSSH Server with additional security configuration

```yaml
- role: vanduc2514.wsl_automation.wsl_sshd
  vars:
    wsl_sshd_distribution_name: Ubuntu-22.04
    wsl_sshd_port: 2222
    wsl_sshd_password_authentication: false
    wsl_sshd_permit_root_login: false
    wsl_sshd_extra_configs:
      MaxAuthTries: 3
      ClientAliveInterval: 300
      PermitEmptyPasswords: false
      LoginGraceTime: 60
```

3. Forward SSH port `2222` to `3322` in Windows. Change the `host_port` and `target_port` base on your setup

```yaml
- role: vanduc2514.wsl_automation.wsl_port_forward
  vars:
    wsl_port_forward_policy_name: WSL-Port-Forward-SSH
    wsl_port_forward_host_port: 3322
    wsl_port_forward_target_port: 2222
```

Verify if WSL Distribution can be access via SSH through LAN

```bash
ssh wsl_user@$WINDOWS_HOST -p 3322
```

4. On router, login to Admin console (or setting page) then forward host port `3322` to Windows's IP address

Verify if WSL Distribution can be access from the internet

```bash
ssh wsl_user@$WINDOWS_EXTERNAL_IP -p 3322
```

### Additional security considerations

- Network firewall
- Additional authentication mechanism (e.g. Two-factor)
- Frequent updates software
- DDoS protection
- Authentication failure monitoring (e.g., fail2ban)
- Security monitoring

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
```

## Additional Resources

For further readings:
- [Ansible Documentation](https://docs.ansible.com)
- [Windows Subsystem for Linux Documentation](https://docs.microsoft.com/en-us/windows/wsl/)

## License

MIT

## Author

Developed by [Duc Nguyen (@vanduc2514)](https://github.com/vanduc2514)
