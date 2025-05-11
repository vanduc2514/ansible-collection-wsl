#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: wsl_slurp
short_description: Read file content from WSL distributions
description:
    - This module is used to read file content from a specific WSL distribution.
    - The file content is returned as a base64 encoded string for safe transmission.
    - This is similar to the C(slurp) module but specifically for WSL environments.
options:
    distribution:
        description:
            - The name of the WSL distribution to use.
        type: str
        required: true
    path:
        description:
            - The absolute path to the file in the WSL distribution to read.
            - This should be a Linux path, not a Windows path.
        type: str
        required: true
notes:
    - This module requires the WSL feature to be enabled on the target Windows system.
    - The target file must be accessible by the specified WSL distribution.
    - Content is returned as base64 encoded to ensure safe transmission of binary data.
seealso:
    - module: ansible.builtin.slurp
    - module: vanduc2514.wsl_automation.wsl_file
author:
    - Your Name (@yourgithubhandle)
'''

EXAMPLES = r'''
- name: Read /etc/passwd from Ubuntu WSL distribution
  vanduc2514.wsl_automation.wsl_slurp:
    distribution: Ubuntu
    path: /etc/passwd
  register: passwd_content

- name: Display the decoded content
  debug:
    msg: "{{ passwd_content.content | b64decode }}"

- name: Read a configuration file
  vanduc2514.wsl_automation.wsl_slurp:
    distribution: Debian
    path: /etc/nginx/nginx.conf
  register: nginx_conf
'''

RETURN = r'''
content:
    description: File content encoded as base64.
    returned: success
    type: str
    sample: "IyBUaGlzIGlzIGEgdGVzdCBmaWxlCgpIZWxsbyBXb3JsZCE="
encoding:
    description: Type of encoding used for the content.
    returned: success
    type: str
    sample: "base64"
path:
    description: Path to the file that was read.
    returned: success
    type: str
    sample: "/etc/hosts"
owner:
    description: Owner of the file.
    returned: success
    type: str
    sample: "root"
mode:
    description: File permission mode.
    returned: success
    type: str
    sample: "644"
'''