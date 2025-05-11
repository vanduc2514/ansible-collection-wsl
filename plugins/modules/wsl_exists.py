#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: wsl_exists
short_description: Check if a file or directory exists in WSL distributions
description:
    - This module checks if a file or directory exists in a specific WSL distribution.
    - Similar to ansible.builtin.stat but specifically for WSL environments.
options:
    distribution:
        description:
            - The name of the WSL distribution to use.
        type: str
        required: true
    path:
        description:
            - The absolute path to check in the WSL distribution.
            - This should be a Linux path, not a Windows path.
        type: str
        required: true
notes:
    - This module requires Windows Subsystem for Linux (WSL) and PowerShell.
    - The target WSL distribution must be installed and configured.
seealso:
    - module: ansible.builtin.stat
    - module: vanduc2514.wsl_automation.wsl_file
    - module: vanduc2514.wsl_automation.wsl_slurp
author:
    - vanduc2514 (vanduc2514@gmail.com)
'''

EXAMPLES = r'''
- name: Check if /etc/hosts exists
  vanduc2514.wsl_automation.wsl_exists:
    distribution: Ubuntu
    path: /etc/hosts
  register: hosts_file

- name: Use the check result
  debug:
    msg: "The file exists: {{ hosts_file.exists }}"

- name: Check if directory exists
  vanduc2514.wsl_automation.wsl_exists:
    distribution: Ubuntu
    path: /etc/nginx
  register: nginx_dir

- name: Show directory existence
  debug:
    msg: "Nginx directory exists: {{ nginx_dir.exists }}"
'''

RETURN = r'''
path:
    description: The path that was checked.
    returned: success
    type: str
    sample: "/etc/hosts"
exists:
    description: Whether the path exists.
    returned: success
    type: bool
    sample: true
'''