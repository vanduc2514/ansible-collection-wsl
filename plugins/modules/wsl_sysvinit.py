#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2023, Your Name <your.name@example.org>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: wsl_sysvinit
short_description: Manage SysVinit services in WSL distributions
description:
    - This module manages SysVinit services in WSL distributions.
    - It can start and stop services using the service command.
    - Requires the WSL distribution to use SysVinit as its init system.
options:
    distribution:
        description:
            - The name of the WSL distribution.
        type: str
        required: true
    name:
        description:
            - Name of the SysVinit service to manage.
        type: str
        required: true
    state:
        description:
            - Whether the service should be started or stopped.
            - Started ensures the service is running.
            - Stopped ensures the service is not running.
        type: str
        choices: [ started, stopped ]
        default: started
notes:
    - This module requires PowerShell.
    - This module requires WSL to be installed and configured.
    - The WSL distribution must use SysVinit as its init system.
    - Requires root access in the WSL distribution to control services.
author:
    - Your Name (@yourgithubusername)
'''

EXAMPLES = r'''
- name: Start apache2 service
  wsl_sysvinit:
    distribution: Debian
    name: apache2
    state: started

- name: Stop mysql service
  wsl_sysvinit:
    distribution: Debian
    name: mysql
    state: stopped

- name: Configure multiple services
  wsl_sysvinit:
    distribution: "{{ item.distro }}"
    name: "{{ item.service }}"
    state: started
  loop:
    - { distro: 'Debian', service: 'apache2' }
    - { distro: 'Debian', service: 'mysql' }
'''

RETURN = r'''
'''
