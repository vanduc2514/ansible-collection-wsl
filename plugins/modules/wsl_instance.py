#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: wsl_instance
short_description: Manages Windows Subsystem for Linux (WSL) instances
description:
  - Creates, removes, stops, and manages WSL distributions on Windows systems.
  - Supports both installation from Microsoft Store and importing custom distributions.
  - Can download and import distributions from URLs.
  - Supports importing from VHD files and Appx bundles.

options:
    name:
        description:
            - Name of the WSL distribution.
            - If the distro does not exist, it will be installed from MS Store / Web.
        type: str
        required: true
        aliases: [ Name ]

    web_download:
        description:
            - Download the distribution from the internet instead of Microsoft Store.
            - Use when installing the distribution.
        type: bool
        default: false

    fs_path:
        description:
            - Path to the filesystem file when importing a distribution.
            - Can be a local file path or HTTP URL.
            - If path is an HTTP URL, distribution will be downloaded / extracted. Support only Appx bundles and rootfs
            - Required when importing a custom distribution.
        type: path
        required: false

    install_dir_path:
        description:
            - Installation directory path when importing a distribution.
            - Required when importing a custom distribution.
        type: path
        required: false

    vhd:
        description:
            - Specify if the filesystem file is a VHD file when importing.
            - Use when importing a custom distribution.
        type: bool
        default: false

    checksum:
        description:
            - Checksum value to validate download Appx bundle or rootfs.
        type: str
        required: false

    checksum_algorithm:
        description:
            - Algorithm to use for checksum validation when downloading Appx bundle or rootfs.
        type: str
        default: sha1
        choices: [ md5, sha1, sha256, sha384, sha512 ]

    delete_fs_download:
        description:
            - Whether to delete the downloaded Appx bundle or rootfs files after import.
        type: bool
        default: false

    is_bundle:
        description:
            - Specify if the downloaded file is an Appx bundle.
            - When true, the module will extract the rootfs from the bundle.
        type: bool
        default: false

    fs_download_path:
        description:
            - Directory to store downloaded Appx bundle or rootfs files.
            - Defaults to host temporary directory if not specified.
        type: path
        required: false

    arch_version:
        description:
            - WSL architecture version to use for the distribution.
        type: int
        default: 2
        choices: [ 1, 2 ]

    state:
        description:
            - Desired state of the WSL distribution.
            - Use 'run' to run a distribution.
            - Use 'stop' to terminate a running distribution.
            - Use 'absent' to unregister and remove a distribution.
        type: str
        default: run
        choices: [ run, stop, absent ]
'''

EXAMPLES = r'''
# Install Ubuntu distribution from Microsoft Store
- name: Install Ubuntu WSL
  wsl_instance:
    name: Ubuntu
    arch_version: 2
    state: run

# Import existing distribution from rootfs
- name: Import custom WSL distribution
  wsl_instance:
    name: CustomLinux
    fs_path: C:\path\to\distribution.tar
    install_dir_path: C:\WSL\CustomLinux
    arch_version: 2
    state: run

# Import distribution from VHD file
- name: Import WSL from VHD
  wsl_instance:
    name: CustomLinux
    fs_path: C:\path\to\distribution.vhdx
    install_dir_path: C:\WSL\CustomLinux
    vhd: true
    state: run

# Download and import distribution from URL
- name: Import WSL from URL
  wsl_instance:
    name: CustomLinux
    fs_path: https://example.com/path/to/rootfs.tar.gz
    install_dir_path: C:\WSL\CustomLinux
    checksum: 1234567890abcdef
    checksum_algorithm: sha256
    delete_fs_download: true
    state: run

# Import AppX bundle distribution
- name: Import WSL from Appx bundle
  wsl_instance:
    name: CustomLinux
    fs_path: https://example.com/path/to/bundle.appx
    install_dir_path: C:\WSL\CustomLinux
    is_bundle: true
    state: run

# Stop a running WSL distribution
- name: Stop WSL distribution
  wsl_instance:
    name: Ubuntu
    state: stop

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

diff:
    description: Information about the WSL distribution before and after changes
    type: dict
    returned: always
    contains:
        before:
            description: WSL distribution state before changes
            type: dict
        after:
            description: WSL distribution state after changes
            type: dict

rootfs_download_path:
    description: Path where the rootfs file was downloaded
    type: str
    returned: when downloading from URL
    sample: C:\Users\user\AppData\Local\Temp\WSLDownloadFS\rootfs.zip

rootfs_download_checksum:
    description: Checksum of the downloaded rootfs file
    type: str
    returned: when downloading from URL

rootfs_bundle_extracted_path:
    description: Path to the extracted rootfs from AppX bundle
    type: str
    returned: when is_bundle is true

rootfs_download_cleaned:
    description: Whether the downloaded rootfs file was cleaned up
    type: bool
    returned: when delete_fs_download is true

rootfs_bundle_extracted_cleaned:
    description: Whether the extracted bundle directory was cleaned up
    type: bool
    returned: when delete_fs_download and is_bundle are true
'''