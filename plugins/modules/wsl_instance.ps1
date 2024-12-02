#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic

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
        rootfs_path = @{
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
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

function Test-WSLDistributionExists {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    try {
        $wslDistros = wsl.exe --list --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        $distributions = $wslDistros -split "`n" | Where-Object { $_.Trim() -eq $Name }
        return $distributions.Count -gt 0
    }
    catch {
        Write-Error "Error checking WSL distribution existence: $_"
        return $false
    }
}

function Install-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [bool]
        $WebDownload,

        [Parameter(Mandatory = $false)]
        [int]
        $Version
    )

    # Build installation extra arguments
    $extraArgs = @() + $(
        if ($WebDownload) { '--web-download' }
    ) -join ' '

    # Initialize return hashtable
    $ret = @{
        changed = $false
        before = wsl.exe --list --verbose
        after = $null
    }

    # Install WSL distribution
    if ($PSCmdlet.ShouldProcess($Name, 'Install WSL Distro')) {
        $installCommand = "wsl.exe --install $Name $extraArgs"
        # Hack for running interactive command in non-interactive shell
        $null = Invoke-CimMethod Win32_Process -MethodName create -Arguments @{
            CommandLine = $installCommand
        }
        $ret.changed = $true
    }

    # Wait for distribution finish installing
    $startTime = Get-Date
    $timeout = New-TimeSpan -Minutes 15

    do {
        Start-Sleep -Seconds 2
        $runningDistros = @(wsl --list --running --quiet) -split "`n" |
                         Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        if ((Get-Date) - $startTime -gt $timeout) {
            throw "Timeout waiting for WSL distribution '$Name' to start"
        }
    } while ($runningDistros -notcontains $Name)

    # Wait for distro auto terminate
    Start-Sleep -Seconds 4

    # Set WSL version if specified
    if ($Version -and $PSCmdlet.ShouldProcess($Name, "Set WSL Architecture version to '$Version'")) {
        $null = wsl.exe --set-version $Name $Version
        $ret.changed = $true
    }

    $ret.after = wsl.exe --list --verbose
    return $ret
}

function Import-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $RootFSPath,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallLocation,

        [Parameter(Mandatory = $false)]
        [int]
        $Version,

        [Parameter(Mandatory = $false)]
        [bool]
        $IsVHD
    )

    # Build installation extra arguments
    $extraArgs = @() + $(
        if ($IsVHD) { '--vhd' }
    ) -join ' '

    # Initialize return hashtable
    $ret = @{
        changed = $false
        before = wsl.exe --list --verbose
        after = $null
    }

    # Import WSL Distro using RootFS
    if ($PSCmdlet.ShouldProcess($Name, 'Import WSL Distro')) {
        wsl.exe --import $Name $InstallLocation $RootFSPath $extraArgs
        $ret.changed = $true
    }

    # Set WSL version if specified
    if ($Version -and $PSCmdlet.ShouldProcess($Name, "Set WSL Architecture version to '$Version'")) {
        $null = wsl.exe --set-version $Name $Version
        $ret.changed = $true
    }

    $ret.after = wsl.exe --list --verbose
    return $ret
}

function Delete-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Initialize return hashtable
    $ret = @{
        changed = $false
        before = wsl.exe --list --verbose
        after = $null
    }

    # Delete (Unregister) WSL Distro
    if ($PSCmdlet.ShouldProcess($Name, 'Delete (Unregister) WSL Distro')) {
        wsl.exe --unregister $Name
        $ret.changed = $true
    }

    $ret.after = wsl.exe --list --verbose
    return $ret
}

function Stop-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]

    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Initialize return hashtable
    $ret = @{
        changed = $false
        before = wsl.exe --list --verbose
        after = $null
    }

    # Stop (Terminate) WSL Distro
    if ($PSCmdlet.ShouldProcess($Name, 'Stop (Terminate) WSL Distro')) {
        wsl.exe --terminate $Name
        $ret.changed = $true
    }

    $ret.after = wsl.exe --list --verbose
    return $ret
}

# Retrieve and validate parameters
$name = $module.Params.name
$state = $module.Params.state
$rootfs_path = $module.Params.rootfs_path
$install_dir = $module.Params.install_dir
$arch_version = $module.Params.arch_version
$web_download = $module.Params.web_download
$vhd = $module.Params.vhd

# Initialize result
$module.Result.changed = $false
$status = $null

try {
    # Check if the distribution exists
    $exists = Test-WSLDistributionExists -Name $name

    # Handle 'absent' state first
    if ($state -eq 'absent') {
        if ($exists) {
            $status = Delete-WSLDistribution -Name $name -WhatIf:$($module.CheckMode)
        }
    }
    # Handle other states
    else {
        # Install/Import if distribution doesn't exist
        if (-not $exists) {
            $status = if ($rootfs_path -and $install_dir) {
                Import-WSLDistribution -Name $name -RootFSPath $rootfs_path -InstallLocation $install_dir -Version $arch_version -IsVHD $vhd -WhatIf:$($module.CheckMode)
            }
            else {
                Install-WSLDistribution -Name $name -WebDownload $web_download -Version $arch_version -WhatIf:$($module.CheckMode)
            }
        }

        # Handle state-specific operations
        switch ($state) {
            'stop' {
                $status = Stop-WSLDistribution -Name $name -WhatIf:$($module.CheckMode)
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

    $module.Result.changed = $module.Result.changed -or $status.changed

    $module.Result.before_value = $status.before
    $module.Result.value = $status.after

    $module.ExitJson()
}
catch {
    $module.FailJson("An unexpected error occurred: $($_.Exception.Message)", $_)
}