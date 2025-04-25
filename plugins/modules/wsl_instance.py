#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: wsl_instance
short_description: Manage Windows Subsystem for Linux (WSL) distributions
description:
  - Install, configure, start, stop, and remove WSL distributions.
  - Supports installing online distributions from Microsoft Store or Web.
  - Supports importing custom distributions from rootfs archives.
  - Allows configuration of WSL distributions through wsl.conf.
  - Manages WSL distribution state (running, stopped, absent).
options:
  distribution:
    description:
      - Name of the WSL distribution.
    type: str
    required: true
  web_download:
    description:
      - Whether to download the distribution from the Microsoft Store.
      - Mutually exclusive with C(rootfs_path)
    type: bool
    default: false
  rootfs_path:
    description:
      - Path to the rootfs archive for importing a custom distribution.
      - Can be a local file path or a URL.
      - If a URL is provided, the file will be downloaded.
      - Mutually exclusive with C(web_download).
    type: str
  rootfs_download_path:
    description:
      - Directory where the rootfs archive will be downloaded.
      - Only used when C(rootfs_path) is a URL.
      - Defaults to the system temporary directory if not specified.
  rootfs_download_checksum:
    description:
      - Checksum for validating the downloaded rootfs archive.
      - Only used when C(rootfs_path) is a URL.
    type: str
  rootfs_download_checksum_algorithm:
    description:
      - Algorithm to use for validating the checksum of downloaded rootfs archive.
      - Only used when C(rootfs_path) is a URL.
    type: str
    choices: [md5, sha1, sha256, sha384, sha512]
    default: md5
    type: str
  import_dir_path:
    description:
      - Directory where the WSL distribution will be installed.
      - Only used when importing a custom distribution with C(rootfs_path).
      - Defaults to C(%ProgramData%\\WSLDistributions\\<distribution>) if not specified.
    type: path
  import_bundle:
    description:
      - Whether the rootfs archive is an Appx bundle (.appx) or (.zip) that contains the rootfs.
      - Only used when C(rootfs_path) is specified.
    type: bool
    default: false
  import_vhd:
    description:
      - Whether to use VHD format when importing the WSL distribution.
      - Only used when C(rootfs_path) is specified.
    type: bool
    default: false
  arch_version:
    description:
      - WSL architecture version to use.
      - Version 1 uses a translation layer for system calls.
      - Version 2 uses a lightweight VM with better compatibility and performance.
    type: int
    choices: [1, 2]
    default: 2
  state:
    description:
      - Desired state of the WSL distribution.
      - C(run) ensures the distribution is running in background.
      - C(stop) ensures the distribution is stopped.
      - C(absent) ensures the distribution is removed.
    type: str
    choices: [run, stop, absent]
    default: stop
notes:
  - This module requires Windows 10 version 1903 or higher, or Windows 11.
  - WSL must be installed and enabled on the system.
seealso:
  - name: WSL Installation Guide
    description: Microsoft's guide for installing WSL
    link: https://learn.microsoft.com/en-us/windows/wsl/install
  - name: WSL Command Reference
    description: Reference for WSL commands
    link: https://learn.microsoft.com/en-us/windows/wsl/basic-commands
author:
  - vanduc2514 (vanduc2514@gmail.com)
'''

EXAMPLES = r'''
- name: Install Ubuntu from Microsoft Store
  ansible.windows.wsl_instance:
    distribution: Ubuntu
    web_download: true
    state: run


- name: Import a custom distribution from a local rootfs archive
  ansible.windows.wsl_instance:
    distribution: CustomLinux
    rootfs_path: C:\path\to\rootfs.tar.gz
    import_dir_path: D:\WSL\CustomLinux
    state: run

- name: Import a custom distribution from a URL
  ansible.windows.wsl_instance:
    distribution: DownloadedLinux
    rootfs_path: https://example.com/path/to/rootfs.tar.gz
    rootfs_download_checksum: a1b2c3d4e5f6...
    rootfs_download_checksum_algorithm: sha256
    state: run

- name: Import a distribution from an Appx bundle
  ansible.windows.wsl_instance:
    distribution: BundledLinux
    rootfs_path: https://example.com/path/to/bundle.zip
    import_bundle: true
    state: run


- name: Change WSL version for a distribution
  ansible.windows.wsl_instance:
    distribution: Ubuntu
    arch_version: 1

- name: Stop a WSL distribution
  ansible.windows.wsl_instance:
    distribution: Ubuntu
    state: stop

- name: Remove a WSL distribution
  ansible.windows.wsl_instance:
    distribution: Ubuntu
    state: absent
'''

RETURN = r'''
'''
