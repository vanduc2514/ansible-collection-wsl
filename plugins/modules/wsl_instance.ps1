#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.WSLDistribution

$spec = @{
    options = @{
        name = @{
            type     = "str"
            required = $true
            aliases  = @("Name")
        }
        state = @{
            type     = "str"
            default  = "run"
            choices  = @("run", "stop", "absent")
        }
        fs_path = @{
            type        = "path"
            required    = $false
        }
        install_dir = @{
            type        = "path"
            required    = $false
        }
        arch_version = @{
            type     = "int"
            default  = 2
            choices  = @(1, 2)
        }
        web_download = @{
            type        = "bool"
            default     = $false
        }
        vhd = @{
            type        = "bool"
            default     = $false
        }
    }
    # TODO: Refine spec with more validation rules
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

function Install-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [bool]
        $WebDownload
    )

    # Build installation extra arguments
    $extraArgs = @() + $(
        if ($WebDownload) { '--web-download' }
    ) -join ' '

    # Initialize return hashtable
    $before_value = (Get-WSLDistribution -Name $Name).Name
    $ret = @{
        changed = $false
        before = $before_value
        after = $Name
    }

    if ($before_value -eq $Name) {
        return $ret
    }
    # Install WSL distribution
    if ($PSCmdlet.ShouldProcess($Name, 'Install WSL Distro')) {
        $installCommand = "wsl.exe --install $Name $extraArgs"
        # Hack for running interactive command in non-interactive shell
        $null = Invoke-CimMethod Win32_Process -MethodName create -Arguments @{
            CommandLine = $installCommand
        }

        # Wait for distribution finish installing
        $startTime = Get-Date
        $timeout = New-TimeSpan -Minutes 15

        do {
            Start-Sleep -Seconds 2
            $distro = Get-WSLDistribution -Name $Name

            if ((Get-Date) - $startTime -gt $timeout) {
                throw "Timeout waiting for WSL distribution '$Name' to finish install"
            }
            # Continue waiting if the state is "Installing"
        } while ($distro.State -eq "Installing")

        # Stop distro after installed
        Stop-WSLDistribution -Name $Name

        $ret.changed = $true
    }

    return $ret
}

function Import-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $FSPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InstallLocation,

        [Parameter(Mandatory = $false)]
        [bool]
        $IsVHD
    )

    # Build installation extra arguments
    $extraArgs = @() + $(
        if ($IsVHD) { '--vhd' }
    ) -join ' '

    # Initialize return hashtable
    $before_value = (Get-WSLDistribution -Name $Name).Name
    $ret = @{
        changed = $false
        before = $before_value
        after = $Name
    }

    if ($before_value -ne $Name) {
        # Import WSL Distro using RootFS
        if ($PSCmdlet.ShouldProcess($Name, 'Import WSL Distro')) {
            wsl.exe --import $Name $InstallLocation $FSPath $extraArgs
            $ret.changed = $true
        }
    }

    return $ret
}

function Delete-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    # Initialize return hashtable
    $before_value = Get-WSLDistribution -Name $Name
    $after_value = $null
    $ret = @{
        changed = $false
        before = $before_value
        after = $after_value
    }

    if ($before_value -ne $after_value) {
        # Delete (Unregister) WSL Distro
        if ($PSCmdlet.ShouldProcess($Name, 'Delete (Unregister) WSL Distro')) {
            wsl.exe --unregister $Name
            $ret.changed = $true
        }
    }

    return $ret
}

function SetVersion-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]
        $Version
    )

    # Initialize return hashtable
    $before_value = (Get-WSLDistribution -Name $Name).Version
    $ret = @{
        changed = $false
        before = $before_value
        after = $Version
    }

    if ($before_value -ne $Version) {
        # Set WSL architecture version for the distro
        if ($PSCmdlet.ShouldProcess($Name, "Set WSL Architecture version to '$Version'")) {
            $null = wsl.exe --set-version $Name $Version
            $ret.changed = $true
        }
    }

    return $ret
}

function Stop-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    # Initialize return hashtable
    $before_value = (Get-WSLDistribution -Name $Name).State
    $after_value = "Stopped"
    $ret = @{
        changed = $false
        before = $before_value
        after = $after_value
    }

    if ($before_value -ne $after_value) {
        # Stop (Terminate) WSL Distro
        if ($PSCmdlet.ShouldProcess($Name, 'Stop (Terminate) WSL Distro')) {
            wsl.exe --terminate $Name
            $ret.changed = $true
        }
    }

    return $ret
}

# Retrieve and validate parameters
$name = $module.Params.name
$state = $module.Params.state
$fs_path = $module.Params.fs_path
$install_dir = $module.Params.install_dir
$arch_version = $module.Params.arch_version
$web_download = $module.Params.web_download
$vhd = $module.Params.vhd

# Initialize result
$module.Result.changed = $false
$status = $null

try {
    if ($state -eq 'absent') {
        $delete_status = Delete-WSLDistribution -Name $name -WhatIf:$($module.CheckMode)
    }
    else {
        $setup_status = if ($fs_path -and $install_dir) {
            Import-WSLDistribution -Name $name -FSPath $fs_path -InstallLocation $install_dir -IsVHD $vhd -WhatIf:$($module.CheckMode)
        }
        else {
            Install-WSLDistribution -Name $name -WebDownload $web_download -WhatIf:$($module.CheckMode)
        }
        $version_status = SetVersion-WSLDistribution -Name $name -Version $arch_version -WhatIf:$($module.CheckMode)

        switch ($state) {
            'stop' {
                $state_status = Stop-WSLDistribution -Name $name -WhatIf:$($module.CheckMode)
            }
        }
    }

    # Set the changed state only once, based on the last operation performed
    if ($status.before) {
        $module.Diff.before = $status.before
    }
    if ($status.after) {
        $module.Diff.after = $status.after
    }

    $module.Result.changed = $delete_status.changed -or $setup_status.changed -or $version_status.changed -or $state_status.changed

    $module.Result.before_value = $status.before
    $module.Result.value = $status.after

    $module.ExitJson()
}
catch {
    $module.FailJson("An unexpected error occurred: $($_.Exception.Message)", $_)
}