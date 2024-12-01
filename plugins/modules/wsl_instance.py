#!/usr/bin/python
# -*- coding: utf-8 -*-
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
            - Use 'install' to install a new distribution.
            - Use 'import' to import an existing distribution.
            - Use 'unregister' to remove a distribution.
        type: str
        default: install
        choices: [ install, import, unregister ]
    source_path:
        description:
            - Path to the source file when using import method.
            - Required if state is 'import'.
        type: path
        required: false
    install_location:
        description:
            - Installation location when using import method.
            - Required if state is 'import'.
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
'''

EXAMPLES = r'''
# Install Ubuntu distribution from Microsoft Store
- name: Install Ubuntu WSL
  wsl_instance:
    name: Ubuntu
    state: install
    version: 2

# Import existing distribution from tar file
- name: Import custom WSL distribution
  wsl_instance:
    name: CustomLinux
    state: import
    source_path: C:\path\to\distribution.tar
    install_location: C:\WSL\CustomLinux
    version: 2

# Import distribution from VHD file
- name: Import WSL from VHD
  wsl_instance:
    name: CustomLinux
    state: import
    source_path: C:\path\to\distribution.vhdx
    install_location: C:\WSL\CustomLinux
    vhd: true

# Unregister WSL distribution
- name: Unregister WSL distribution
  wsl_instance:
    name: Ubuntu
    state: unregister
'''

RETURN = r'''
changed:
    description: Whether the WSL distribution was modified
    type: bool
    returned: always
    sample: true
'''