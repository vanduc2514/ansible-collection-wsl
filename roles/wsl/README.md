# Ansible role: wsl

## Requirements

- Windows 10 version 1903 or higher, or Windows 11
- WSL feature must be installed and enabled

## Role Variables

### Basic Variables

These variables control how `wsl` is installed

| Variable | Description | Default |
|:---------|:------------|:---------|
|`wsl_arch_version`| The WSL architecture version for new distributions (1 or 2) | `2` |
|`wsl_version`| The WSL binary version from WSL Github Repository | `2.3.26` |
|`wsl_state`| Controls WSL state: 'present' (installed), 'absent' (removed), or 'shutdown' (terminate all WSL instances and VM) | `present` |
|`wsl_config_shutdown_when_changed` | Whether to shutdown wsl when config changed | `false` |

### WSL Configuration Variables

The role uses the following configuration structure. For detailed information about these settings, refer to the [Official Microsoft WSL Configuration Documentation](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

| Variable | Description | Default |
|:---------|:------------|:---------|
|`wsl_config_memory`| How much memory to assign to the WSL 2 VM | `4GB` |
|`wsl_config_processors`| How many processors to assign to the WSL 2 VM | `2` |
|`wsl_config_localhost_forwarding`| Enable localhost forwarding from WSL to Windows | `true` |
|`wsl_config_gui_applications`| Enable support for GUI applications (WSLg) | `true` |
|`wsl_config_page_reporting`| Enable Windows to reclaim unused memory from WSL 2 | `true` |
|`wsl_config_kernel`| Absolute Windows path to a custom Linux kernel | - |
|`wsl_config_kernel_modules`| Absolute Windows path to custom Linux kernel modules VHD | - |
|`wsl_config_kernel_command_line`| Additional kernel command line arguments | - |
|`wsl_config_swap`| How much swap space to add to the WSL 2 VM | - |
|`wsl_config_swap_file`| Absolute Windows path to the swap virtual hard disk | - |

#### Windows 11 Specific WSL Configuration Variables

| Variable | Description | Default |
|:---------|:------------|:---------|
|`wsl_config_debug_console`| Show debug console output | - |
|`wsl_config_nested_virtualization`| Enable nested virtualization | - |
|`wsl_config_vm_idle_timeout`| VM idle timeout in milliseconds | - |
|`wsl_config_auto_proxy`| Use Windows HTTP proxy settings | - |

#### Windows 11 22H2+ Specific WSL Configuration Variables

| Variable | Description | Default |
|:---------|:------------|:---------|
|`wsl_config_networking_mode`| Network mode (NAT/mirrored) | - |
|`wsl_config_firewall`| Enable Windows Firewall rules | - |
|`wsl_config_dns_tunneling`| Enable DNS tunneling | - |

#### Experimental Features

| Variable | Description | Default |
|:---------|:------------|:---------|
|`wsl_config_experimental_sparse_vhd`| Enable sparse VHD for WSL | - |
|`wsl_config_experimental_auto_memory_reclaim`| Configure automatic memory reclaim behavior | - |
|`wsl_config_experimental_best_effort_dns_parsing`| Enable best effort DNS parsing | - |
|`wsl_config_experimental_dns_tunneling_ip_address`| DNS tunneling IP address | - |
|`wsl_config_experimental_initial_auto_proxy_timeout`| Initial auto proxy timeout in milliseconds | - |
|`wsl_config_experimental_ignored_ports`| Comma-separated list of ignored ports | - |
|`wsl_config_experimental_host_address_loopback`| Enable host address loopback | - |

### Extra Configuration

The role supports adding custom configuration sections through the `wsl_config_extra` variable. This allows you to add any additional configuration sections that might not be covered by the standard variables.

Example:
```yaml
wsl_config_extra:
  custom_section:
    property1: value1
    property2: value2
```

This will generate:
```ini
[custom_section]
property1 = value1
property2 = value2
```

## Example Playbook

Install wsl with configuration

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl
      vars:
        wsl_config_memory: 8GB
        wsl_config_processors: 4
        wsl_config_experimental_sparse_vhd: true
        wsl_config_experimental_auto_memory_reclaim: dropCache
```

Shutdown all WSL instances and the WSL 2 VM

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl
      vars:
        wsl_state: shutdown
```

## License

MIT

## Author Information

Duc Nguyen ([@vanduc2514](https://github.com/vanduc2514))
