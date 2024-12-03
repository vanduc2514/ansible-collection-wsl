#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.WSLDistribution
#AnsibleRequires -PowerShell ..module_utils.WebRequest

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
    param(
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $false)]
        [bool]
        $WebDownload
    )

    $extraArgs = @() + $(
        if ($WebDownload) { '--web-download' }
    ) -join ' '

    if ($PSCmdlet.ShouldProcess($Name, 'Install WSL distribution')) {
        $installCommand = "wsl --install $Name $extraArgs"
        # Hack for running interactive command in non-interactive shell
        $proc = Invoke-CimMethod Win32_Process -MethodName create -Arguments @{
            CommandLine = $installCommand
        }
        if ($proc.ReturnValue -ne 0) {
            $Module.FailJson("Failed to install WSL distribution '$Name'.")
        }

        # Wait for distribution installed
        $startTime = Get-Date
        $timeout = New-TimeSpan -Minutes 15
        do {
            Start-Sleep -Seconds 2
            $distro = Get-WSLDistribution -Name $Name

            if ((Get-Date) - $startTime -gt $timeout) {
                $Module.FailJson("Timeout waiting for WSL distribution '$Name' to finish install.")
            }
        } while ($distro.State -eq "Installing")
        Stop-WSLDistribution -Name $Name -Module $Module

        try {
            $query = "Select * from Win32_Process where ProcessId = '$($proc.ProcessId)'"
            Remove-CimInstance -Query $query
        } catch {
            $Module.Warn("Failed to remove wsl installation process: $($_.Exception.Message)", $_)
        }
        $Module.Result.changed = $true
    }
}

function Import-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $FSPath,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDirectoryPath,

        [Parameter(Mandatory = $false)]
        [string]
        $FSDownloadPath,

        [Parameter(Mandatory = $false)]
        [string]
        $ChecksumAlgorithm

        [Parameter(Mandatory = $false)]
        [string]
        $Checksum

        [Parameter(Mandatory = $false)]
        [bool]
        $ShouldDeleteFSDownload

        [Parameter(Mandatory = $false)]
        [bool]
        $IsVHD

        [Parameter(Mandatory = $false)]
        [bool]
        $IsBundle
    )

    # TODO: Move this to spec instead
    if (-not $FSDownloadPath) {
        $FSDownloadPath = Join-Path -Path $Module.Tmpdir -ChildPath "WSLDownloadFS"
    }
    if (-not (Test-Path -Path $FSDownloadPath)) {
        New-Item -ItemType Directory -Path $FSDownloadPath -Force | Out-Null
    }

    $extraArgs = @() + $(
        if ($IsVHD) { '--vhd' }
    ) -join ' '
    $fs_path = $FSPath

    if ($FSPath.StartsWith('http', [System.StringComparison]::InvariantCultureIgnoreCase)) {
        $rootfs_download_dest = $null
        $download_script = {
            param($Response, $Stream)

            $random_zip_path = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetRandomFileName(), "zip")
            $rootfs_download_dest = Join-Path -Path $FSDownloadPath -ChildPath $random_zip_path
            $rootfs = [System.IO.File]::Create($rootfs_download_dest)
            try {
                $Stream.CopyTo($rootfs)
                $rootfs.Flush()
            }
            finally {
                $rootfs.Dispose()
            }

            if ($Checksum -and $Checksum -ne $tmp_checksum) {
                $tmp_checksum = Get-Checksum -Path $rootfs_download_dest -Algorithm $ChecksumAlgorithm
                $Module.FailJson("Failed checksum for download rootfs, '$tmp_checksum' did not match '$Checksum'")
            }

            $Module.Result.rootfs_download_path = $rootfs_download_dest
            $Module.Result.rootfs_download_checksum = $tmp_checksum
        }
        $web_request = Get-AnsibleWindowsWebRequest -Uri $FSPath -Module $Module

        try {
            Invoke-AnsibleWindowsWebRequest -Module $Module -Request $web_request -Script $download_script
        }
        catch {
            $Module.FailJson("Failed to dowload rootfs from '$FSPath': $($_.Exception.Message)", $_)
        }

        if ($ISBundle) {
            $base_name = [System.IO.Path]::GetFileNameWithoutExtension($rootfs_download_dest)
            $extract_dir = Join-Path -Path $FSDownloadPath -ChildPath $base_name
            New-Item -ItemType Directory -Path $extract_dir -Force | Out-Null

            try {
                Expand-Archive -Path $rootfs_download_dest -DestinationPath $extract_dir -Force
            }
            catch {
                $Module.FailJson("Failed to extract rootfs bundle from '$rootfs_download_dest': $($_.Exception.Message)", $_)
            }

            $rootfs_extracted = Get-ChildItem -Path $extract_dir -Recurse |
                Where-Object { $_.Name -match 'install\.tar(\.gz)?$' } |
                Select-Object -First 1
            if (-not $rootfs_extracted) {
                $Module.FailJson("Failed to find rootfs file in the extracted bundle")
            }

            $fs_path = $rootfs_extracted.FullName
            $Module.Result.rootfs_bundle_extracted_path = $fs_path
        }
        else {
            $fs_path = $rootfs_download_dest
        }
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Import WSL distribution')) {
        try {
            wsl --import $Name $InstallDirectoryPath $fs_path $extraArgs
            $Module.Result.changed = $true
        } catch {
            $Module.FailJson("Failed to import WSL distribution '$Name': $($_.Exception.Message)", $_)
        }
    }

    if ($ShouldDeleteFSDownload) {
        if ($rootfs_download_dest -and (Test-Path -Path $rootfs_download_dest)) {
            try {
                Remove-Item -Path $rootfs_download_dest -Force
                $Module.Result.rootfs_download_cleaned = $true
            }
            catch {
                $Module.Warn("Failed to cleanup downloaded file '$rootfs_download_dest': $($_.Exception.Message)", $_)
            }
        }

        if ($ISBundle -and $extract_dir -and (Test-Path -Path $extract_dir)) {
            try {
                Remove-Item -Path $extract_dir -Recurse -Force
                $Module.Result.rootfs_bundle_extracted_cleaned = $true
            }
            catch {
                $Module.Warn("Failed to cleanup extracted directory '$extract_dir': $($_.Exception.Message)", $_)
            }
        }
    }
}

function SetVersion-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [int]
        $Version
    )

    if ($PSCmdlet.ShouldProcess($Name, "Set architecture version '$Version' for WSL distribution '$Name'")) {
        try {
            wsl --set-version $Name $Version
            $Module.Result.changed = $true
        } catch {
            $Module.FailJson("Failed to set architecture version '$Version' for WSL distribution '$Name': $($_.Exception.Message)", $_)
        }
    }

    return $ret
}

function Delete-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    if ($PSCmdlet.ShouldProcess($Name, 'Delete (Unregister) WSL distribution')) {
        try {
            wsl --unregister $Name
            $Module.Result.changed = $true
        } catch {
            $Module.FailJson("Failed to delete (unregister) WSL distribution '$Name'.")
        }
    }
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

if ($state -eq 'absent') {
    $delete_status = Delete-WSLDistribution -Name $name -WhatIf:$($module.CheckMode)
}
else {
    $setup_status = if ($fs_path -and $install_dir) {
        Import-WSLDistribution -Name $name -FSPath $fs_path -InstallDirectoryPath $install_dir -IsVHD $vhd -WhatIf:$($module.CheckMode)
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

$module.Exception()
