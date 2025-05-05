# Ansible Collection - vanduc2514.wsl_automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🤔 The Story

Picture this: You have an old laptop gathering dust in your closet. It's not quite ready for retirement, but Windows is making it wheeze like it just ran a marathon. Your tech-savvy friend suggests Linux, but the thought of diving into that rabbit hole makes you break into a cold sweat. ("How do I exit Vim?" will haunt your dreams).

What if you could have the best of both worlds? Run Linux inside Windows without the commitment? Even better - what if you could turn that old laptop into a 24/7 home server without selling your soul to the cloud providers?

But wait, there's more! Remember that time when you spent weeks perfecting your WSL setup, only to have it vanish into the digital void with one mistaken command ? Or maybe you're just tired of manually configuring the same WSL setup across different machines?

Enter `vanduc2514.wsl_automation` - your gateway to WSL automation nirvana.

## 💡 The Magic Behind It

This collection is deceptively simple yet powerful. It works by executing WSL commands (`wsl`) on Windows hosts through Ansible, turning complex WSL management into repeatable, automated tasks.

## 🎯 What You Need

You probably already have most of what you need! Here's the checklist:

### System Requirements
| Requirement | Details |
|------------|---------|
| Operating System | Windows 10 (version 1903+) or Windows 11 |
| WSL Feature | Enabled (don't worry, we'll handle this for you!) |
| Hardware | Any PC/laptop that can run Windows 10/11 |

### The Ansible Bits

Just make sure you have:

- ansible-core >= 2.15.0
- ansible-galaxy

That's all! Everything else will be handled automatically when you install the collection.

### What You Don't Need
- Cloud subscriptions
- Expensive hardware
- A Computer Science degree
- The ability to exit Vim

Just your trusty old PC and a dream of Linux glory!

## ✨ The Easy Path: Roles

Want to get started quickly? These roles are like pre-packed recipes for your WSL automation needs.

### wsl

The foundation of your WSL kingdom:

```yaml
- role: vanduc2514.wsl_automation.wsl
  vars:
    wsl_config_memory: 4GB
    wsl_config_processors: 4
```

This role ensure `wsl` kernel and features are installed in your system. Without this, wsl distribution cannot be created. After executing this role, the windows machine will have `wsl` command available.

[Full recipe book here](roles/wsl/README.md)

### wsl_distribution

Your Linux distribution, your rules:

```yaml
- role: vanduc2514.wsl_automation.wsl_distribution
  vars:
    wsl_distribution_name: Ubuntu-22.04
    wsl_distribution_config_user_default: "wslmaster"
```

This role install a wsl distribution in your system with additional configurations. It can also keep the wsl distribution running in the background like a windows process.

[Detailed configuration guide](roles/wsl_distribution/README.md)

### wsl_sshd

This role makes sure OpenSSH Server `sshd`  is installed and running in a wsl distribution. This allows accessing wsl distribution via SSH connection from a remote machine.

There are these ways of configuring SSH access but you need to choose your networking adventure (wisely):

#### 🕵️ The Secret Lair Path

The safest way - keep your WSL accessible only through your Windows machine as a secure jump host. Perfect for personal use and a peace of mind:

```yaml
- role: vanduc2514.wsl_automation.wsl_sshd
  vars:
    wsl_sshd_distribution_name: Ubuntu-22.04
    wsl_sshd_port: 2222
    wsl_sshd_port_forward_enabled: false
```

To connect, you'll use Windows as your secret entrance:
```bash
ssh -J windows_host wsl_user@localhost -p 2222
```

#### 🌍 The Public Server Path

⚠️ **WARNING**: Exposing your WSL to the internet is like opening Pandora's box - make sure you know what you're doing! This is just the beginning of what you need to consider for security. Consult with security experts or your tech-savvy friends before proceeding.

If you're brave enough to venture this path, here's your starter kit for security:

1. First, set up your WSL with proper security:

```yaml
- role: vanduc2514.wsl_automation.wsl_distribution
  vars:
    wsl_distribution_name: Ubuntu-22.04
    wsl_distribution_config_user_default: "wsluser"
    wsl_distribution_config_user_default_password: "SuperStrongPassword123!"  # Change this!
    wsl_distribution_config_user_default_authorized_keys:
      # Your SSH public key
      - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

2. Then configure SSH with strict security settings:

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

3. This is just the beginning! You'll need to:
   - Configure your router's port forwarding to the `wsl_sshd_port_forward_host_port`
   - Set up proper firewall rules
   - Consider intrusion detection systems
   - Regularly monitor your logs
   - Keep your system updated
   - Consider fail2ban for brute force protection
   - Think about DDoS protection
   - And much more...

Remember: The internet is a dangerous place. If you're not sure about security, stick with the [Secret Lair Path](#️-the-secret-lair-path). Your WSL will thank you! 🛡️

[SSH adventure manual](roles/wsl_sshd/README.md)

## 🧙‍♂️ The Tech Wizard Path: Modules

For those who want fine-grained control, our modules let you orchestrate WSL like a symphony:

| Module | Your Power |
|--------|------------|
| wsl_instance | Create/destroy WSL instances |
| wsl_file | Manage WSL file and directory |
| wsl_package | Install packages, works with difference distribution |
| wsl_user | Basic management for users |
| wsl_systemd | Control services with `systemd` |
| wsl_sysvinit | Control services with legacy `sysvinit` |
| wsl_slurp | Get content of a file encoded by `base64` |

## 🚀 Quick Start

Getting started is as easy as:
```bash
ansible-galaxy collection install vanduc2514.wsl_automation
```

### Install from GitHub

If you want the latest development version, you can install directly from GitHub:

```bash
ansible-galaxy collection install git+https://github.com/vanduc2514/ansible-collection-wsl-automation.git
```

That's it! The installation will automatically handle all the dependencies for you. Now you're ready to turn that old laptop into a Linux powerhouse!

### The "I Just Want It to Work" Playbook

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl
    - role: vanduc2514.wsl_automation.wsl_distribution
    - role: vanduc2514.wsl_automation.wsl_sshd
```

### A More Typical Example Playbook

```yaml
- hosts: windows
  roles:
    # Configure WSL system-wide settings
    - role: vanduc2514.wsl_automation.wsl
      vars:
        wsl_config_memory: 4GB
        wsl_config_processors: 4
        wsl_config_swap: 2GB
        wsl_config_swap_file: "D:\\wsl\\swap.vhdx"

    # Set up an Ubuntu distribution with custom user
    - role: vanduc2514.wsl_automation.wsl_distribution
      vars:
        wsl_distribution_name: Ubuntu-22.04
        wsl_distribution_config_user_default: "wsluser"
        wsl_distribution_config_user_default_password: "{{ vault_wsl_user_password }}"
        wsl_distribution_config_user_default_authorized_keys:
          - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
        wsl_distribution_config_automount_options:
          enabled: true
          mountFsTab: true
          root: "/mnt"

    # Configure SSH access with secure defaults
    - role: vanduc2514.wsl_automation.wsl_sshd
      vars:
        wsl_sshd_distribution_name: Ubuntu-22.04
        wsl_sshd_port: 2222
        wsl_sshd_password_authentication: false
        wsl_sshd_permit_root_login: false
        wsl_sshd_port_forward_enabled: false
        wsl_sshd_authorized_keys:
          - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
```

💡 **Tip**: Store sensitive values like passwords in an Ansible vault file!

## 📚 Learn More

Want to dive deeper? Check out:
- [Ansible Documenation](https://docs.ansible.com)
- [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/)

## License

MIT

## Author

Made with ❤️ by [Duc Nguyen (@vanduc2514)](https://github.com/vanduc2514)
