#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2023, Your Name <your.name@example.org>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: wsl_package
short_description: Manage packages in WSL distributions
description:
    - This module manages packages in various WSL distributions.
    - It can install, upgrade, and remove packages.
    - It supports various package managers (apt, dnf, yum, zypper, pacman, apk).
    - It automatically detects the appropriate package manager for the distribution.
options:
    distribution:
        description:
            - The name of the WSL distribution.
        type: str
        required: true
    name:
        description:
            - Name of the package to install, upgrade, or remove.
        type: str
        required: true
    version:
        description:
            - Specific version of the package to install or upgrade to.
            - If not specified, the latest available version will be installed.
            - Ignored when state=absent.
        type: str
        required: false
    force:
        description:
            - Whether to force the package manager to take the specified action.
            - For installation, this might override package dependency issues.
            - For removal, this might force the removal of dependent packages.
        type: bool
        default: false
    update_cache:
        description:
            - Update the package list cache before performing any operation.
            - Equivalent to running 'apt-get update', 'dnf check-update', etc. depending on the package manager.
        type: bool
        default: false
    state:
        description:
            - Whether the package should be present or absent.
            - If state=present, the package will be installed if not already present, or upgraded if version is specified and differs.
            - If state=absent, the package will be removed if present.
        type: str
        choices: [ present, absent ]
        default: present
notes:
    - This module requires PowerShell.
    - This module requires WSL to be installed and configured.
    - The module automatically detects the appropriate package manager for the distribution.
    - Supported package managers: apt (Debian/Ubuntu), dnf (Fedora), yum (CentOS/RHEL), zypper (openSUSE), pacman (Arch), and apk (Alpine).
author:
    - Your Name (@yourgithubusername)
'''

EXAMPLES = r'''
- name: Install the latest version of a package
  wsl_package:
    distribution: Ubuntu
    name: nginx
    state: present

- name: Install a specific version of a package
  wsl_package:
    distribution: Ubuntu
    name: nginx
    version: 1.18.0
    state: present

- name: Update package cache and install a package
  wsl_package:
    distribution: Ubuntu
    name: nginx
    update_cache: true
    state: present

- name: Remove a package
  wsl_package:
    distribution: Ubuntu
    name: nginx
    state: absent

- name: Force installation of a package
  wsl_package:
    distribution: Ubuntu
    name: nginx
    force: true
    state: present

- name: Install packages in different distributions
  wsl_package:
    distribution: "{{ item.distro }}"
    name: "{{ item.package }}"
    state: present
  loop:
    - { distro: 'Ubuntu', package: 'nginx' }
    - { distro: 'Fedora', package: 'httpd' }
    - { distro: 'Alpine', package: 'lighttpd' }
'''

RETURN = r'''
'''