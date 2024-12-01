#!powershell
# AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{
            type     = "str"
            required = $true
            aliases  = @("Name")
            description = "Name of the WSL distribution."
        }
        state = @{
            type     = "str"
            default  = "install"
            choices  = @("install", "import", "unregister")
            description = "Desired state of the WSL distribution."
        }
        source_path = @{
            type        = "path"
            required    = $false
            description = "Path to the source for importing the WSL distribution."
        }
        install_location = @{
            type        = "path"
            required    = $false
            description = "Path where the WSL distribution will be installed."
        }
        version = @{
            type     = "int"
            default  = 2
            choices  = @(1, 2)
            description = "WSL version to set for the distribution."
        }
        no_launch = @{
            type        = "bool"
            default     = $false
            description = "Do not launch the distribution after installation."
        }
        web_download = @{
            type        = "bool"
            default     = $false
            description = "Use web download during installation."
        }
        vhd = @{
            type        = "bool"
            default     = $false
            description = "Import the distribution as a virtual hard disk (VHD)."
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
        $wslOutput = wsl.exe --list --verbose 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Failed to list WSL distributions: $wslOutput"
            return $false
        }

        $distributions = $wslOutput -split "`n" | Select-Object -Skip 1 | Where-Object { $_ -match "^\s*\S+\s+$Name\s+" }
        return $distributions.Count -gt 0
    }
    catch {
        Write-Error "Error checking WSL distribution existence: $_"
        return $false
    }
}

Function Install-WSLDistribution {
    param(
        [string]$Name,
        [bool]$NoLaunch,
        [bool]$WebDownload,
        [int]$Version
    )

    try {
        $args = @("--install", "--name", $Name)

        if ($NoLaunch) {
            $args += "--no-launch"
        }
        if ($WebDownload) {
            $args += "--web-download"
        }

        Write-Verbose "Executing: wsl.exe $($args -join ' ')"
        $result = Start-Process -FilePath "wsl.exe" -ArgumentList $args -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($result.ExitCode -eq 0) {
            if ($Version -eq 1) {
                Write-Verbose "Setting WSL architecture version 1 for '$Name'."
                wsl.exe --set-version $Name 1 | Out-Null
            }
            Write-Verbose "WSL distribution '$Name' installed successfully."
            return $true
        }
        else {
            Write-Error "wsl.exe exited with code $($result.ExitCode) during installation."
            return $false
        }
    }
    catch {
        Write-Error "Exception during installation of '$Name': $_"
        return $false
    }
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

        $success = Install-WSLDistribution -Name $name -NoLaunch $no_launch -WebDownload $web_download -Version $version
        if (-not $success) {
            # FIXME: Do I need to specify changed= = false if the module fails ?
            $module.FailJson("Failed to install WSL distribution '$name'.")
        }
        $module.Result.changed = $true
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