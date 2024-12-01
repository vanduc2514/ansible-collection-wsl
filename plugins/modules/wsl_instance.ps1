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
            default  = "present"
            choices  = @("present", "absent")
            description = "Desired state of the WSL distribution."
        }
        method = @{
            type     = "str"
            default  = "install"
            choices  = @("install", "import")
            description = "Method to install the WSL distribution."
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

# FIXME: Method Naming and implementation does not match
Function Assert-WSLDistributionExists {
    <#
    .SYNOPSIS
    Checks if a WSL distribution exists.

    .PARAMETER Name
    The name of the WSL distribution.

    .RETURNS
    <Boolean> True if the distribution exists; otherwise, False.
    #>
    param([string]$Name)

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
        Write-Error "Error checking WSL distributions: $_"
        return $false
    }
}

Function Install-WSLDistribution {
    <#
    .SYNOPSIS
    Installs a WSL distribution using the install method.

    .PARAMETER Name
    The name of the WSL distribution.

    .PARAMETER NoLaunch
    If set, the distribution will not be launched after installation.

    .PARAMETER WebDownload
    If set, the installation will use web download.

    .PARAMETER Version
    The WSL version to set for the distribution.

    .RETURNS
    <Boolean> True if installation succeeds; otherwise, False.
    #>
    param(
        [string]$Name,
        [bool]$NoLaunch,
        [bool]$WebDownload,
        [int]$Version
    )

    try {
        $args = @("--install", $Name)

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
    <#
    .SYNOPSIS
    Imports a WSL distribution from a source path.

    .PARAMETER Name
    The name of the WSL distribution.

    .PARAMETER SourcePath
    The path to import the distribution from.

    .PARAMETER InstallLocation
    The location to install the distribution.

    .PARAMETER Version
    The WSL version to set for the distribution.

    .PARAMETER IsVHD
    If set, imports the distribution as a VHD.

    .RETURNS
    <Boolean> True if import succeeds; otherwise, False.
    #>
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
    <#
    .SYNOPSIS
    Removes a WSL distribution.

    .PARAMETER Name
    The name of the WSL distribution.

    .RETURNS
    <Boolean> True if removal succeeds; otherwise, False.
    #>
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
    $method = $module.Params.method
    $source_path = $module.Params.source_path
    $install_location = $module.Params.install_location
    $version = $module.Params.version
    $no_launch = $module.Params.no_launch
    $web_download = $module.Params.web_download
    $vhd = $module.Params.vhd

    $module.Result.changed = $false

    # Check if the distribution exists
    $exists = Assert-WSLDistributionExists -Name $name

    if ($state -eq "present" -and -not $exists) {
        Write-Verbose "WSL distribution '$name' does not exist. Proceeding to create."

        if ($module.CheckMode) {
            $module.Result.changed = $true
        }
        else {
            if ($method -eq "install") {
                $success = Install-WSLDistribution -Name $name -NoLaunch $no_launch -WebDownload $web_download -Version $version
            }
            elseif ($method -eq "import") {
                $success = Import-WSLDistribution -Name $name -SourcePath $source_path -InstallLocation $install_location -Version $version -IsVHD $vhd
            }
            else {
                $module.FailJson("Invalid method specified: $method. Allowed methods are 'install' and 'import'.")
            }

            if (-not $success) {
                $module.FailJson("Failed to create WSL distribution '$name'.")
            }
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "absent" -and $exists) {
        Write-Verbose "WSL distribution '$name' exists. Proceeding to remove."

        if ($module.CheckMode) {
            $module.Result.changed = $true
        }
        else {
            $success = Remove-WSLDistribution -Name $name
            if (-not $success) {
                $module.FailJson("Failed to remove WSL distribution '$name'.")
            }
            $module.Result.changed = $true
        }
    }
    else {
        Write-Verbose "No changes required for WSL distribution '$name'. Desired state '$state' is already achieved."
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("An unexpected error occurred: $($_.Exception.Message)", $_)
}