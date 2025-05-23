#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: wsl_user
short_description: Manage users in Windows Subsystem for Linux (WSL) distributions
description:
  - Create, modify, and remove user accounts in WSL distributions.
  - Configure user properties including home directory, shell, and UID.
  - Manage sudo privileges.
  - Set user passwords.
  - This module is intended for basic initial user setup in WSL distributions only. For advanced user management, please use ansible.builtin.user module.
options:
  distribution:
    description:
      - Name of the WSL distribution where the user account should be managed.
    type: str
    required: true
  name:
    description:
      - Name of the user account to manage.
    type: str
    required: true
  uid:
    description:
      - User ID (UID) for the account.
      - Only used when creating a new user or modifying an existing one.
      - Won't have any effect if the specified user is root
    type: int
  home_path:
    description:
      - Absolute path to the user's home directory.
      - If not specified, defaults to /home/<username>.
    type: str
  login_shell:
    description:
      - Path to the user's login shell.
      - Example: /bin/bash, /bin/sh, etc.
    type: str
  sudo:
    description:
      - If C(true), grant the user sudo privileges without password.
      - If C(false), remove sudo privileges.
      - Won't have any effect if the specified user is root
    type: bool
    default: false
  password:
    description:
      - Password (hashed) for the user account.
      - If this is omitted, the account will be created without a password.
      - If C(unlock_no_password) is true, the account will be unlocked after creation.
    type: str
    no_log: true
  password_update:
    description:
      - Update the user password (hashed) with the given value
      - Module always C(changed) if this value is set
    type: str
    no_log: true
  unlock_no_password:
    description: If C(true), unlocks the user when creating a new user without a password.
    type: bool
    default: true
  remove_home:
    description:
      - When C(state=absent), also remove the user's home directory.
    type: bool
    default: false
  state:
    description:
      - Whether the user account should exist or not.
    type: str
    choices: [ present, absent ]
    default: present
notes:
  - Requires Windows Subsystem for Linux (WSL) and PowerShell.
  - The target WSL distribution must be installed and configured.
  - The module operates using PowerShell and WSL commands.
  - Sudo access is granted by creating a sudoers.d file for the user with NOPASSWD access.
seealso:
  - name: Windows Subsystem for Linux Documentation
    description: Microsoft's official WSL documentation
    link: https://learn.microsoft.com/en-us/windows/wsl/
author:
  - vanduc2514 (vanduc2514@gmail.com)
'''

EXAMPLES = r'''
- name: Create a user in Ubuntu WSL
  vanduc2514.wsl_automation.wsl_user:
    distribution: Ubuntu
    name: myuser
    state: present

- name: Create user with custom settings
  vanduc2514.wsl_automation.wsl_user:
    distribution: Ubuntu
    name: customuser
    uid: 1500
    login_shell: /bin/bash
    home_path: /home/customuser

- name: Create admin user
  vanduc2514.wsl_automation.wsl_user:
    distribution: Ubuntu
    name: admin
    sudo: true
    password: "secretpassword"


- name: Remove user
  vanduc2514.wsl_automation.wsl_user:
    distribution: Ubuntu
    name: olduser
    state: absent

- name: Remove user completely
  vanduc2514.wsl_automation.wsl_user:
    distribution: Ubuntu
    name: olduser
    state: absent
    remove_home: true
'''

RETURN = r'''
user:
  description: Information about the managed user account.
  returned: success and state is present
  type: dict
  contains:
    name:
      description: Username of the account
      type: str
      sample: myuser
    uid:
      description: User ID of the account
      type: int
      sample: 1000
    home_path:
      description: Home directory path
      type: str
      sample: /home/myuser
    login_shell:
      description: Login shell path
      type: str
      sample: /bin/bash
    sudo:
      description: Whether the user has sudo privileges
      type: bool
      sample: false
  sample:
    name: myuser
    uid: 1000
    home_path: /home/myuser
    login_shell: /bin/bash
    sudo: false
'''
