#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        state = @{
            type = "str"
            default = "present"
            choices = @("present", "absent")
        }
        method = @{
            type = "str"
            default = "install"
            choices = @("install", "import")
        }
        source_path = @{
            type = "path"
            required = $false
        }
        install_location = @{
            type = "path"
            required = $false
        }
        version = @{
            type = "int"
            default = 2
            choices = @(1, 2)
        }
        no_launch = @{
            type = "bool"
            default = $false
        }
        web_download = @{
            type = "bool"
            default = $false
        }
        vhd = @{
            type = "bool"
            default = $false
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

Function Get-WSLDistribution {
    param($Name)
    try {
        $wslOutput = wsl.exe --list --verbose
        $distributions = $wslOutput -split "`n" | Select-Object -Skip 1 | Where-Object { $_ -match $Name }
        if ($distributions) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

Function Install-WSLDistribution {
    param(
        $Name,
        $NoLaunch,
        $WebDownload,
        $Version
    )

    $args = @("--install", $Name)

    if ($NoLaunch) {
        $args += "--no-launch"
    }
    if ($WebDownload) {
        $args += "--web-download"
    }

    $result = Start-Process -FilePath "wsl.exe" -ArgumentList $args -Wait -PassThru -NoNewWindow

    if ($result.ExitCode -eq 0) {
        if ($Version -eq 1) {
            wsl.exe --set-version $Name 1
        }
        return $true
    }
    return $false
}

Function Import-WSLDistribution {
    param(
        $Name,
        $SourcePath,
        $InstallLocation,
        $Version,
        $IsVHD
    )

    $args = @("--import", $Name, $InstallLocation, $SourcePath)

    if ($IsVHD) {
        $args += "--vhd"
    }

    $result = Start-Process -FilePath "wsl.exe" -ArgumentList $args -Wait -PassThru -NoNewWindow

    if ($result.ExitCode -eq 0) {
        if ($Version -eq 1) {
            wsl.exe --set-version $Name 1
        }
        return $true
    }
    return $false
}

Function Remove-WSLDistribution {
    param($Name)

    $result = Start-Process -FilePath "wsl.exe" -ArgumentList @("--unregister", $Name) -Wait -PassThru -NoNewWindow
    return ($result.ExitCode -eq 0)
}

try {
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

    $exists = Get-WSLDistribution -Name $name

    if ($state -eq "present" -and -not $exists) {
        if ($module.CheckMode) {
            $module.Result.changed = $true
        }
        else {
            if ($method -eq "install") {
                $success = Install-WSLDistribution -Name $name -NoLaunch $no_launch -WebDownload $web_download -Version $version
            }
            else {
                if (-not $source_path -or -not $install_location) {
                    $module.FailJson("source_path and install_location are required for import method")
                }
                $success = Import-WSLDistribution -Name $name -SourcePath $source_path -InstallLocation $install_location -Version $version -IsVHD $vhd
            }

            if (-not $success) {
                $module.FailJson("Failed to create WSL distribution $name")
            }
            $module.Result.changed = $true
        }
    }
    elseif ($state -eq "absent" -and $exists) {
        if ($module.CheckMode) {
            $module.Result.changed = $true
        }
        else {
            $success = Remove-WSLDistribution -Name $name
            if (-not $success) {
                $module.FailJson("Failed to remove WSL distribution $name")
            }
            $module.Result.changed = $true
        }
    }

    $module.ExitJson()
}
catch {
    $module.FailJson("Error occurred: $($_.Exception.Message)", $_)
}