# Ansible Role: wsl_port_forward

This role configures port forwarding and firewall rules from Windows host to WSL distribution, enabling access to services running in WSL from the Windows host or network.

## Requirements

- Windows 10 version 1903 or higher, or Windows 11
- WSL feature must be installed and enabled
- WSL distribution must be installed and configured
- PowerShell 5.1 or higher
- Windows administrator privileges

## Role Variables

| Variable Name | Description | Required | Default | Type |
|--------------|-------------|----------|---------|------|
| `wsl_port_forward_policy_id` | The unique identifier for the Windows Firewall rule. This identifier helps identify and manage the firewall rule. | no | `WSL Port Forward` | string |
| `wsl_port_forward_host_port` | The port number to listen on the Windows host. This is the port that will be accessible from Windows and other machines on the network (if allowed by the firewall). | yes | - | integer |
| `wsl_port_forward_target_port` | The port number to forward to in the WSL distribution. This is the port where your service is running inside WSL. | yes | - | integer |
| `wsl_port_forward_state` | The desired state of the port forwarding configuration ('present' or 'absent'). When 'present', creates or updates the port forwarding and firewall rule. When 'absent', removes both. | no | `present` | string |

## Examples

### Basic SSH Port Forwarding

Forward SSH port from WSL to Windows host:

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_port_forward
      vars:
        wsl_port_forward_policy_id: WSL-SSH-Service
        wsl_port_forward_host_port: 3322
        wsl_port_forward_target_port: 2222
```

### Web Server Port Forwarding

Forward a web server running in WSL:

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_port_forward
      vars:
        wsl_port_forward_policy_id: WSL-Web-Service
        wsl_port_forward_host_port: 9080
        wsl_port_forward_target_port: 80
```

### Multiple Port Forwards

Set up multiple port forwards by including the role multiple times:

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_port_forward
      vars:
        wsl_port_forward_policy_id: WSL-SSH-Service
        wsl_port_forward_host_port: 3322
        wsl_port_forward_target_port: 2222

    - role: vanduc2514.wsl_automation.wsl_port_forward
      vars:
        wsl_port_forward_policy_id: WSL-Web-Service
        wsl_port_forward_host_port: 9080
        wsl_port_forward_target_port: 80
```

### Remove Port Forwarding

Remove a specific port forwarding configuration:

```yaml
- hosts: windows
  roles:
    - role: vanduc2514.wsl_automation.wsl_port_forward
      vars:
        wsl_port_forward_policy_id: WSL-SSH-Service
        wsl_port_forward_state: absent
```

## Notes

- The role automatically detects the WSL distribution's IP address and will reconfigure port forwarding if it changes
- Port forwarding is configured using Windows' built-in `netsh interface portproxy` functionality
- A Windows Firewall rule is automatically created/updated to allow incoming connections on the host port

## License

MIT

## Author Information

Duc Nguyen (@vanduc2514)
