#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2024, Duc Nguyen Van <vanduc2514@gmail.com>
# MIT License (see LICENSE)

DOCUMENTATION = r'''
---
module: wsl_instance
short_description: Manages Windows Subsystem for Linux (WSL) instances
description:
    - Creates, removes, and manages WSL distributions on Windows systems.
    - Supports both installation from Microsoft Store and importing existing distributions.
options:
    name:
        description:
            - Name of the WSL distribution.
        type: str
        required: true
    state:
        description:
            - Desired state of the WSL distribution.
        type: str
        default: present
        choices: [ present, absent ]
    method:
        description:
            - Method to use when creating the WSL distribution.
            - Use 'install' for Microsoft Store installations.
            - Use 'import' for importing existing distributions.
        type: str
        default: install
        choices: [ install, import ]
    source_path:
        description:
            - Path to the source file when using import method.
            - Required if method is 'import'.
        type: path
        required: false
    install_location:
        description:
            - Installation location when using import method.
            - Required if method is 'import'.
        type: path
        required: false
    version:
        description:
            - WSL version to use for the distribution.
        type: int
        default: 2
        choices: [ 1, 2 ]
    no_launch:
        description:
            - Do not launch the distribution after installation.
        type: bool
        default: false
    web_download:
        description:
            - Download the distribution from the internet instead of Microsoft Store.
        type: bool
        default: false
    vhd:
        description:
            - Specify if the source file is a VHD file (for import method).
        type: bool
        default: false
author:
    - Your Name (@github_handle)
'''

EXAMPLES = r'''
# Install Ubuntu distribution from Microsoft Store
- name: Install Ubuntu WSL
  wsl_instance:
    name: Ubuntu
    state: present
    method: install
    version: 2

# Import existing distribution from tar file
- name: Import custom WSL distribution
  wsl_instance:
    name: CustomLinux
    state: present
    method: import
    source_path: C:\path\to\distribution.tar
    install_location: C:\WSL\CustomLinux
    version: 2

# Import distribution from VHD file
- name: Import WSL from VHD
  wsl_instance:
    name: CustomLinux
    state: present
    method: import
    source_path: C:\path\to\distribution.vhdx
    install_location: C:\WSL\CustomLinux
    vhd: true

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
'''

from ansible.module_utils.basic import AnsibleModule

def main():
    # This is just a placeholder as the actual implementation
    # is in the PowerShell script
    module = AnsibleModule(
        argument_spec=dict(
            name=dict(type='str', required=True),
            state=dict(type='str', default='present', choices=['present', 'absent']),
            method=dict(type='str', default='install', choices=['install', 'import']),
            source_path=dict(type='path', required=False),
            install_location=dict(type='path', required=False),
            version=dict(type='int', default=2, choices=[1, 2]),
            no_launch=dict(type='bool', default=False),
            web_download=dict(type='bool', default=False),
            vhd=dict(type='bool', default=False),
        ),
        supports_check_mode=True
    )

    module.exit_json(changed=False)

if __name__ == '__main__':
    main()