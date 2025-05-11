#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: wsl_systemd
short_description: Manage systemd services in WSL distributions
description:
    - This module manages systemd services in WSL distributions.
    - It can start and stop services using systemctl.
    - Requires the WSL distribution to have systemd enabled and running.
options:
    distribution:
        description:
            - The name of the WSL distribution.
        type: str
        required: true
    name:
        description:
            - Name of the systemd service to manage.
            - Do not include the .service suffix.
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
            - When not specified, the service's enabled state will remain unchanged.
        type: bool
        default: null
    daemon_reload:
        description:
            - Run systemctl daemon-reload before doing any other operations.
            - This is useful when new or changed unit files have been installed.
            - Daemon-reload runs regardless of whether the module starts/stops or enables/disables anything.
        type: bool
        default: false
notes:
    - This module requires PowerShell.
    - This module requires WSL to be installed and configured.
    - The WSL distribution must have systemd enabled and running.
    - Requires root access in the WSL distribution to control services.
author:
    - Your Name (@yourgithubusername)
'''

EXAMPLES = r'''
- name: Start nginx service
  wsl_systemd:
    distribution: Ubuntu
    name: nginx
    state: started

- name: Stop postgresql service
  wsl_systemd:
    distribution: Ubuntu
    name: postgresql
    state: stopped

- name: Start and enable nginx service
  wsl_systemd:
    distribution: Ubuntu
    name: nginx
    state: started
    enabled: true

- name: Stop and disable postgresql service
  wsl_systemd:
    distribution: Ubuntu
    name: postgresql
    state: stopped
    enabled: false

- name: Reload systemd daemon and restart service
  wsl_systemd:
    distribution: Ubuntu
    name: myservice
    daemon_reload: true
    state: started

- name: Just enable a service without changing its running state
  wsl_systemd:
    distribution: Ubuntu
    name: myservice
    enabled: true

- name: Ensure multiple services are started
  wsl_systemd:
    distribution: "{{ item.distro }}"
    name: "{{ item.service }}"
    state: started
  loop:
    - { distro: 'Ubuntu', service: 'nginx' }
    - { distro: 'Ubuntu', service: 'postgresql' }
'''

RETURN = r'''
'''
