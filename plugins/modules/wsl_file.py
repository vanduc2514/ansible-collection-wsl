#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2023, Your Name <your.name@example.org>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: wsl_file
short_description: Manage files and directories in WSL distributions
description:
    - This module manages files and directories in WSL distributions.
    - It can create, modify, and remove files or directories.
    - It can set file content, append to existing files, and manage ownership and permissions.
options:
    distribution:
        description:
            - The name of the WSL distribution.
        type: str
        required: true
    path:
        description:
            - Path to the file or directory in the WSL distribution.
            - This should be a Linux-style path.
        type: str
        required: true
    content:
        description:
            - Content to write to the file.
            - Cannot be used when state=directory.
        type: str
        required: false
    append:
        description:
            - Whether to append the content to the file instead of overwriting.
            - Only valid when state=file.
        type: bool
        default: false
    recursive:
        description:
            - Remove files and directories recursively.
            - Only valid when state=absent.
        type: bool
        default: false
    force:
        description:
            - Force the operation.
            - When state=absent, force removal of files and directories.
        type: bool
        default: false
    owner:
        description:
            - Owner of the file or directory.
        type: str
        required: false
    mode:
        description:
            - Permission mode of the file or directory.
            - This should be a Linux-style mode (e.g., '644', '755').
        type: str
        required: false
    state:
        description:
            - Whether the file or directory should exist.
            - If state=file, a file will be created or updated.
            - If state=directory, a directory will be created.
            - If state=absent, the file or directory will be removed.
        type: str
        choices: [ file, directory, absent ]
        default: file
notes:
    - This module requires PowerShell.
    - This module requires WSL to be installed and configured.
author:
    - Your Name (@yourgithubusername)
'''

EXAMPLES = r'''
- name: Create a file with content
  wsl_file:
    distribution: Ubuntu
    path: /home/user/test.txt
    content: "Hello, World!"
    state: file
    owner: user
    mode: '644'

- name: Append content to a file
  wsl_file:
    distribution: Ubuntu
    path: /home/user/test.txt
    content: "Additional content"
    append: true
    state: file

- name: Create a directory
  wsl_file:
    distribution: Ubuntu
    path: /home/user/testdir
    state: directory
    owner: user
    mode: '755'

- name: Remove a file
  wsl_file:
    distribution: Ubuntu
    path: /home/user/test.txt
    state: absent

- name: Remove a directory and all its contents
  wsl_file:
    distribution: Ubuntu
    path: /home/user/testdir
    state: absent
    recursive: true
    force: true
'''

RETURN = r'''
path:
    description: Path to the file or directory.
    type: str
    returned: always
    sample: "/home/user/test.txt"
file_info:
    description: Information about the file or directory.
    type: dict
    returned: success
    contains:
        path:
            description: Path to the file or directory.
            type: str
            sample: "/home/user/test.txt"
        exists:
            description: Whether the file or directory exists.
            type: bool
            sample: true
        is_directory:
            description: Whether the path is a directory.
            type: bool
            sample: false
        owner:
            description: Owner of the file or directory.
            type: str
            sample: "user"
        mode:
            description: Permission mode of the file or directory.
            type: str
            sample: "644"
        content:
            description: Content of the file if it's not a directory.
            type: str
            sample: "Hello, World!"
'''