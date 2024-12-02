#!/usr/bin/python
# -*- coding: utf-8 -*-
DOCUMENTATION = r'''
---
module: wsl_instance
short_description: Manages Windows Subsystem for Linux (WSL) instances
description:
    - Creates, removes, stops, and manages WSL distributions on Windows systems.
    - Supports both installation from Microsoft Store and importing existing distributions.
options:
    name:
        description:
            - Name of the WSL distribution.
            - If the distro is not exist, it will be installed from MS Store / Web
        type: str
        required: true
    state:
        description:
            - Desired state of the WSL distribution.
            - Use 'run' to run a distribution.
            - Use 'stop' to terminate a running distribution.
            - Use 'absent' to unregister and remove a distribution.
        type: str
        default: run
        choices: [ run, stop, absent ]
    fs_path:
        description:
            - Path to the root filesystem file when importing a distribution.
            - Required when importing a custom distribution.
        type: path
        required: false
    install_dir:
        description:
            - Installation path when importing a distribution. Must be a directory
            - Required when importing a custom distribution.
        type: path
        required: false
    arch_version:
        description:
            - WSL architecture version to use for the distribution.
        type: int
        default: 2
        choices: [ 1, 2 ]
    web_download:
        description:
            - Download the distribution from the internet instead of Microsoft Store.
            - Use when install the distribution
        type: bool
        default: false
    vhd:
        description:
            - Specify if the rootfs file is a VHD file when importing.
            - Use when importing a custom distribution.
        type: bool
        default: false
'''

EXAMPLES = r'''
# Install Ubuntu distribution from Microsoft Store
- name: Install Ubuntu WSL
  wsl_instance:
    name: Ubuntu
    arch_version: 2
    state: run

# Import existing distribution from rootfs
- name: Import custom WSL distribution
  wsl_instance:
    name: CustomLinux
    fs_path: C:\path\to\distribution.tar
    install_dir: C:\WSL\CustomLinux
    arch_version: 2
    state: run

# Import distribution from VHD file
- name: Import WSL from VHD
  wsl_instance:
    name: CustomLinux
    fs_path: C:\path\to\distribution.vhdx
    install_dir: C:\WSL\CustomLinux
    vhd: true
    state: run

# Stop a running WSL distribution
- name: Stop WSL distribution
  wsl_instance:
    name: Ubuntu
    state: stop

# Remove WSL distribution
- name: Remove WSL distribution
  wsl_instance:
    name: Ubuntu
    state: absent
'''

RETURN = r'''
changed:
    description: Whether the WSL distribution was modified
    type: bool
    returned: always
    sample: true
before_value:
    description: WSL distribution list before changes
    type: str
    returned: always
value:
    description: WSL distribution list after changes
    type: str
    returned: always
'''