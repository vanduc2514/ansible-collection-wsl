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
            default  = "install"
            choices  = @("install", "import", "unregister")
        }
        source_path = @{
            type        = "path"
            required    = $false
        }
        install_location = @{
            type        = "path"
            required    = $false
        }
        version = @{
            type     = "int"
            default  = 2
            choices  = @(1, 2)
        }
        no_launch = @{
            type        = "bool"
            default     = $false
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

Function Test-WSLDistributionExists {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    try {
        $wslDistros = wsl.exe --list --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Failed to list WSL distributions: $wslDistros"
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

        [Parameter(Mandatory = $true)]
        [bool]
        $NoLaunch,

        [Parameter(Mandatory = $true)]
        [bool]
        $WebDownload,

        [Parameter(Mandatory = $false)]
        [int]
        $Version
    )

    # Build installation extra arguments
    $extraArgs = @() + $(
        if ($NoLaunch) { '--no-launch' }
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

    # Wait for distribution to run
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

    # Set WSL version if specified
    if ($Version -and $PSCmdlet.ShouldProcess($Name, "Set WSL Architecture version to '$Version'")) {
        $null = wsl.exe --set-version $Name $Version
        $ret.changed = $true
    }

    $ret.after = wsl.exe --list --verbose
    return $ret
}

Function Import-WSLDistribution {
    param(
        [string]$Name,
        [string]$SourcePath,
        [string]$InstallLocation,
        [int]$Version,
        [bool]$IsVHD
    )

    try {
        $args = @("--import", $Name, $InstallLocation, $SourcePath)

        if ($IsVHD) {
            $args += "--vhd"
        }

        Write-Verbose "Executing: wsl.exe $($args -join ' ')"
        $result = Start-Process -FilePath "wsl.exe" -ArgumentList $args -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($result.ExitCode -eq 0) {
            if ($Version -eq 1) {
                Write-Verbose "Setting WSL version for '$Name' to 1."
                wsl.exe --set-version $Name 1 | Out-Null
            }
            Write-Verbose "WSL distribution '$Name' imported successfully."
            return $true
        }
        else {
            Write-Error "wsl.exe exited with code $($result.ExitCode) during import."
            return $false
        }
    }
    catch {
        Write-Error "Exception during import of '$Name': $_"
        return $false
    }
}

Function Remove-WSLDistribution {
    param([string]$Name)

    try {
        Write-Verbose "Executing: wsl.exe --unregister $Name"
        $result = Start-Process -FilePath "wsl.exe" -ArgumentList @("--unregister", $Name) -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($result.ExitCode -eq 0) {
            Write-Verbose "WSL distribution '$Name' removed successfully."
            return $true
        }
        else {
            Write-Error "wsl.exe exited with code $($result.ExitCode) during removal."
            return $false
        }
    }
    catch {
        Write-Error "Exception during removal of '$Name': $_"
        return $false
    }
}

try {
    # Retrieve and validate parameters
    $name = $module.Params.name
    $state = $module.Params.state
    $source_path = $module.Params.source_path
    $install_location = $module.Params.install_location
    $version = $module.Params.version
    $no_launch = $module.Params.no_launch
    $web_download = $module.Params.web_download
    $vhd = $module.Params.vhd

    # Initialize result
    $module.Result.changed = $false

    # Check if the distribution exists
    $exists = Test-WSLDistributionExists -Name $name

    if ($state -eq "install" -and -not $exists) {
        Write-Verbose "WSL distribution '$name' does not exist. Proceeding to install."

        $status = Install-WSLDistribution -Name $name -NoLaunch $no_launch -WebDownload $web_download -Version $version -WhatIf:$($module.CheckMode)
        if (-not $status) {
            # FIXME: Do I need to specify changed= = false if the module fails ?
            $module.FailJson("Failed to install WSL distribution '$name'.")
        }
        $module.Result.changed = $module.Result.changed -or $status.changed
    }
    elseif ($state -eq "import" -and -not $exists) {
        Write-Verbose "WSL distribution '$name' does not exist. Proceeding to import."

        $success = Import-WSLDistribution -Name $name -SourcePath $source_path -InstallLocation $install_location -Version $version -IsVHD $vhd
        if (-not $success) {
            # FIXME: Do I need to specify changed= = false if the module fails ?
            $module.FailJson("Failed to import WSL distribution '$name'.")
        }
        $module.Result.changed = $true
    }
    elseif ($state -eq "unregister" -and $exists) {
        Write-Verbose "WSL distribution '$name' exists. Proceeding to unregister."

        $success = Remove-WSLDistribution -Name $name
        if (-not $success) {
            $module.FailJson("Failed to unregister WSL distribution '$name'.")
        }
        $module.Result.changed = $true
    }
    else {
        Write-Verbose "No changes required for WSL distribution '$name'. Desired state '$state' is already achieved."
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("An unexpected error occurred: $($_.Exception.Message)", $_)
}