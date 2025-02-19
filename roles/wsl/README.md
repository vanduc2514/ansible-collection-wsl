wsl
=========

An Ansible role to automate the installation and configuration of Windows Subsystem for Linux (WSL) and WSL kernel on Windows hosts.

Dependencies
------------

This role depends on ansible windows collection

* [ansible.windows](https://galaxy.ansible.com/ui/repo/published/ansible/windows/)
* [community.general](https://galaxy.ansible.com/ui/repo/published/community/general/)

Make sure all of the dependencies are installed using

```bash
ansible-galaxy install -r requirements.yaml
```

Role Variables
--------------

| Variable | Description | Default |
|:---------|:------------|:---------|
|`wsl_arch_version`| The WSL architecture version for new distributions (1 or 2) | `2` |
|`wsl_version`| The WSL binary version from WSL Github Repository | `2.3.26` |
|`wsl_state`| Whether the WSL binary should be installed (present) or removed (absent) | `present` |
|`wsl_config`| (Optional) WSL configuration settings in YAML format ||
|`wsl_config_state`| Whether the WSL binary configuration should be created (present) or removed (absent). | `present` |

Example Playbook
----------------

* The following is an example playbook that enable Windows Subsystem for Linux features and install WSL kernel

```yaml
- hosts: ...
  roles:
    - wsl_automation.wsl
```

License
-------

MIT

Author
------------------

* [vanduc2514](https://github.com/vanduc2514)
