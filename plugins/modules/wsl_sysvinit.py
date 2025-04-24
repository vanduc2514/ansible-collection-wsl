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
    - It can configure service runlevels using update-rc.d.
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
    enabled:
        description:
            - Whether the service should start on boot.
            - C(true) means the service will start on boot.
            - C(false) means the service will not start on boot.
        type: bool
        default: false
    runlevel:
        description:
            - The runlevel at which the service should be configured.
            - '0' is halt
            - '1' is single-user mode
            - '2' is multi-user mode without networking
            - '3' is multi-user mode with networking
            - '4' is user-definable
            - '5' is multi-user mode with GUI
            - '6' is reboot
        type: str
        choices: [ '0', '1', '2', '3', '4', '5', '6' ]
        default: '3'
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

- name: Configure apache2 to start on boot at runlevel 3
  wsl_sysvinit:
    distribution: Debian
    name: apache2
    enabled: true
    runlevel: '3'

- name: Disable mysql service and stop it
  wsl_sysvinit:
    distribution: Debian
    name: mysql
    state: stopped
    enabled: false

- name: Configure multiple services
  wsl_sysvinit:
    distribution: "{{ item.distro }}"
    name: "{{ item.service }}"
    state: started
    enabled: true
    runlevel: "{{ item.runlevel | default('3') }}"
  loop:
    - { distro: 'Debian', service: 'apache2' }
    - { distro: 'Debian', service: 'mysql', runlevel: '2' }
'''

RETURN = r'''
'''