#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: wsl_user
short_description: Manage users in Windows Subsystem for Linux (WSL) distributions
description:
  - Create, modify, and remove user accounts in WSL distributions.
  - Set user properties like home directory, shell, and group membership.
  - Configure SSH authorized keys for user authentication.
  - Grant or revoke sudo privileges.
options:
  name:
    description:
      - Name of the user account.
    type: str
    required: true
  distribution:
    description:
      - Name of the WSL distribution where the user account should be managed.
    type: str
    required: true
  comment:
    description:
      - Comment/description for the user account.
    type: str
    default: ""
  create_home:
    description:
      - Whether to create the user's home directory.
    type: bool
    default: true

  group:
    description:
      - Primary group for the user account.
    type: str
  groups:
    description:
      - List of supplementary groups for the user account.
    type: list
    elements: str
  append:
    description:
      - If C(true), add the user to the groups specified in C(groups) without removing from other groups.
      - If C(false), set the user's supplementary groups to exactly the list specified in C(groups).
    type: bool
    default: false
  home:
    description:
      - Home directory path for the user account.
    type: str
  shell:
    description:
      - Login shell for the user account.
    type: str
  password:
    description:
      - Password for the user account.
      - This is not idempotent and will always apply the change when specified.
    type: str
    no_log: true
  ssh_key:
    description:
      - SSH public key content to add to the user's authorized_keys file.
      - Mutually exclusive with C(ssh_key_file).
    type: str
  ssh_key_file:
    description:
      - Path to a file containing SSH public key to add to the user's authorized_keys file.
      - Mutually exclusive with C(ssh_key).
    type: path
  system:
    description:
      - If C(true), create a system account.
      - Only applies when creating a new user.
    type: bool
    default: false
  uid:
    description:
      - User ID for the user account.
    type: int
  sudo:
    description:
      - If C(true), configure sudo access for the user.
      - Will create a sudoers.d file granting passwordless sudo access.
    type: bool
    default: false
  remove:
    description:
      - If C(true), remove the user's home directory when removing the account.
      - Only applies when C(state=absent).
    type: bool
    default: false
  state:
    description:
      - Whether the user account should exist or not.
    type: str
    choices: [present, absent]
    default: present
notes:
  - This module requires the WSL distribution to be installed and properly configured.
  - The module will attempt to start the distribution if it's not running.
  - When setting authorized SSH keys, it will replace any existing keys.
  - For proper operation, the WSL distribution must have the required user management tools installed.
seealso:
  - name: Linux User Management Commands
    description: Documentation for commands like useradd, usermod, and userdel
    link: https://man7.org/linux/man-pages/man8/useradd.8.html
  - name: WSL User Management
    description: Microsoft's guide for managing users in WSL
    link: https://learn.microsoft.com/en-us/windows/wsl/user-support
author:
  - vanduc2514 (vanduc2514@gmail.com)
'''

EXAMPLES = r'''
- name: Create a user account in Ubuntu WSL distribution
  vanduc2514.wsl_automation.wsl_user:
    name: ansible
    distribution: Ubuntu
    comment: Ansible automation user
    groups: sudo
    shell: /bin/bash

- name: Create a user with sudo access
  vanduc2514.wsl_automation.wsl_user:
    name: admin
    distribution: Debian
    sudo: true
    password: "secure_password"
    state: present

- name: Configure SSH access for a user
  vanduc2514.wsl_automation.wsl_user:
    name: deploy
    distribution: Ubuntu
    ssh_key: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC..."
    shell: /bin/bash

- name: Configure SSH access using a key file
  vanduc2514.wsl_automation.wsl_user:
    name: deploy
    distribution: Ubuntu
    ssh_key_file: /path/to/public_key.pub
    shell: /bin/bash

- name: Add a user to specific groups
  vanduc2514.wsl_automation.wsl_user:
    name: devuser
    distribution: Ubuntu
    groups:
      - sudo
      - docker
      - developers
    append: true

- name: Create a system user
  vanduc2514.wsl_automation.wsl_user:
    name: app
    distribution: Ubuntu
    system: true
    home: /opt/app
    shell: /usr/sbin/nologin

- name: Update an existing user's properties
  vanduc2514.wsl_automation.wsl_user:
    name: existing_user
    distribution: Ubuntu
    shell: /bin/zsh
    home: /home/custom_home
    comment: Updated user description

- name: Remove a user account
  vanduc2514.wsl_automation.wsl_user:
    name: olduser
    distribution: Ubuntu
    state: absent

- name: Remove a user account and their home directory
  vanduc2514.wsl_automation.wsl_user:
    name: olduser
    distribution: Ubuntu
    state: absent
    remove: true
'''

RETURN = r'''
user:
  description: Final state of the user account with all properties.
  returned: success and state is present
  type: dict
  sample:
    name: ansible
    uid: 1001
    gid: 1001
    group: ansible
    groups:
      - sudo
      - docker
    home: /home/ansible
    shell: /bin/bash
    comment: Ansible automation user
    sudo: true
    exists: true
'''