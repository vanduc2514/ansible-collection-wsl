#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Common
#AnsibleRequires -PowerShell ..module_utils.WSL
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.WebRequest

$spec = @{
    options = @{
        name = @{
            type     = "str"
            required = $true
        }
        web_download = @{
            type        = "bool"
            default     = $false
        }
        rootfs_path = @{
            type        = "str"
        }
        rootfs_download_path = @{
            type     = "path"
        }
        rootfs_download_checksum = @{
            type     = "str"
        }
        rootfs_download_checksum_algorithm = @{
            type     = "str"
            choices  = @("md5", "sha1", "sha256", "sha384", "sha512")
            default  = "md5"
        }
        import_dir_path = @{
            type        = "path"
        }
        import_bundle = @{
            type     = "bool"
            default  = $false
        }
        import_vhd = @{
            type        = "bool"
            default     = $false
        }
        arch_version = @{
            type     = "int"
            choices  = @(1, 2)
            default  = 2
        }
        config = @{
            type = "str"
        }
        state = @{
            type     = "str"
            choices  = @("run", "stop", "absent")
            default  = "stop"
        }
    }
    supports_check_mode = $true
    mutually_exclusive = @(
        , @("web_download", "rootfs_path")
    )
}


function Get-WSLDistribution {
    param(
        [string]
        $DistributionName,

        [string]
        $ConfigPath
    )

    # Get all available distributions
    $distributions = List-WSLDistribution

    if (-not $distributions) {
        return $null
    }

    foreach ($distro in $distributions) {
        # If the distro found in distributions
        if ($distro.name -eq $DistributionName) {
            if ($ConfigPath) {
                $getConfigArguments = @{
                    DistributionName = $DistributionName
                    ConfigPath = $ConfigPath
                    Stop = $('Stopped' -eq $distro.state)
                }
                $member = @{
                    MemberType = 'NoteProperty'
                    Name = 'config'
                    Value = Get-WSLDistributionConfig @getConfigArguments
                }
                $distro | Add-Member @member
            }
            return $distro
        }
    }

    return $null
}


function Get-WSLDistributionConfig {
    param(
        [string]
        $DistributionName,

        [string]
        $ConfigPath,

        # Whether to stop after fetch configuration
        [bool]
        $Stop = $false
    )

    try {
        $wslConfig = Get-WSLFileContent -DistributionName $DistributionName -Path $ConfigPath
    } catch {
        throw "Failed to get config of WSL distribution '$DistributionName': $($_.Exception.Message)"
    }

    if ($Stop) {
        Stop-WSLDistribution -DistributionName $DistributionName
    }

    return $wslConfig
}


function List-WSLDistribution {
    $wslDistros = Invoke-WSLCommand -Arguments @("--list", "--verbose")

    # Split the output into lines and remove empty lines
    # Skip the header line and process the remaining lines
    $lines = $wslDistros -split "\r\n" | Where-Object { $_ -ne '' } | Select-Object -Skip 1

    # Create an array to store the distribution objects
    $distributions = @()

    foreach ($line in $lines) {
        # Split on multiple spaces and remove empty elements and asterisk
        $parts = $line -split '\s+' | Where-Object { $_ -ne '' -and $_ -ne '*' }

        if ($parts -and $parts.Count -gt 0) {
            $distro = [PSCustomObject]@{
                name    = $parts[0]
                state   = $parts[1]
                arch_version = $parts[2]
            }
        }

        $distributions += $distro
    }

    return $distributions
}


function Install-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [bool]
        $WebDownload
    )

    $extraArgument = @() + $(
        if ($WebDownload) { '--web-download' }
    ) -join ' '

    # TODO: List online distros and test if contains $DistributionName

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Install WSL distribution')) {
        $wslArgument = "--install $DistributionName $extraArgument"
        Invoke-WSLCommandInBackground -Argument $wslArgument

        WaitFor-WSLDistributionState -DistributionName $DistributionName -TimeoutSeconds 600
        Stop-WSLDistribution -DistributionName $DistributionName
    }

}


function Import-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Ansible.Basic.AnsibleModule]
        $Module,

        [string]
        $DistributionName,

        [string]
        $ImportDirectoryPath,

        [string]
        $RootFSPath,

        [string]
        $RootFSDownloadPath,

        [string]
        $RootFSDownloadChecksum,

        [string]
        $RootFSDownloadChecksumAlgorithm,

        [bool]
        $ImportVHD,

        [bool]
        $ImportBundle
    )

    $rootfsPath = $RootFSPath

    $extraArgument = @() + $(
        if ($ImportVHD) { '--vhd' }
    ) -join ' '

    # If the path is an URL, handle download
    if ($rootfsPath.StartsWith('http') -and $PSCmdlet.ShouldProcess($DistributionName, 'Download WSL distribution')) {
        $rootfsUrlHash = Get-HashFromURL -Url $rootfsPath
        $rootfsDownloadExtension = ".tar.gz"
        if ($ImportBundle) {
            $rootfsDownloadExtension = ".zip"
        }
        $rootfsDownloadFileName = $rootfsUrlHash + $rootfsDownloadExtension
        $rootfsDownloadPath = Join-Path -Path $RootFSDownloadPath -ChildPath $rootfsDownloadFileName

        $rootfsDownloadScript = {
            param($Response, $Stream)

            $rootfs = [System.IO.File]::Create($rootfsDownloadPath)
            try {
                $Stream.CopyTo($rootfs)
                $rootfs.Flush()
            }
            finally {
                $rootfs.Dispose()
            }

            if ($RootFSDownloadChecksum) {
                $getFileHashArgument = @(
                    Path = $rootfsDownloadPath
                    Algorithm = $RootFSDownloadChecksumAlgorithm
                )
                $downloadedChecksum = (Get-FileHash @getFileHashArgument).Hash.toLower()
                if ($downloadedChecksum -ne $RootFSDownloadChecksum) {
                    Remove-Item -Path $rootfsDownloadPath -Force | Out-Null
                    throw "Failed Checksum ($RootFSDownloadChecksumAlgorithm) Check for download rootfs, '$downloadedChecksum' did not match '$RootFSDownloadChecksum'"
                }
            }
        }

        if (-not $(Test-Path -Path $rootfsDownloadPath)) {
            $webRequest = Get-AnsibleWindowsWebRequest -Uri $rootfsPath

            try {
                Invoke-AnsibleWindowsWebRequest -Module $Module -Request $webRequest -Script $rootfsDownloadScript
            }
            catch {
                throw "Failed to download rootfs from '$rootfsPath': $($_.Exception.Message)"
            }
        }

        # If the URL points to a Appx bundle, extract it and get the rootfs inside
        if ($ImportBundle -and $PSCmdlet.ShouldProcess($DistributionName, 'Extract WSL distribution bundle')) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($rootfsDownloadPath)
            $rootfsDownloadPathParent = Split-Path -Path $rootfsDownloadPath -Parent
            $rootfsExtractDir = Join-Path -Path $rootfsDownloadPathParent -ChildPath $baseName

            try {
                Expand-Archive -Path $rootfsDownloadPath -DestinationPath $rootfsExtractDir -Force | Out-Null
            }
            catch {
                throw "Failed to extract rootfs bundle from '$rootfsDownloadPath': $($_.Exception.Message)"
            }

            $rootfsExtracted = Get-ChildItem -Path $rootfsExtractDir -Recurse |
                Where-Object { $_.Name -match '\.tar(\.gz)?$' } |
                Select-Object -First 1
            if (-not $rootfsExtracted) {
                throw "Failed to find rootfs file in the extracted bundle for WSL distribution: $DistributionName"
            }

            $rootfsPath = $rootfsExtracted.FullName
        }
        else {
            $rootfsPath = $rootfsDownloadPath
        }
    }

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Import WSL distribution')) {
        try {
            $wslArguments = @(
                "--import", $DistributionName,
                $ImportDirectoryPath, $rootfsPath
                $extraArgument
            )
            Invoke-WSLCommand -Arguments $wslArguments | Out-Null
        } catch {
            throw "Failed to import WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Set-WSLDistributionConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $ConfigPath,

        [string]
        $Config
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Configure WSL distribution')) {
        try {
            $setWSLFileContentArguments = @{
                DistributionName = $DistributionName
                Path = $ConfigPath
                Content = $Config
            }
            Set-WSLFileContent @setWSLFileContentArguments | Out-Null
        } catch {
            throw "Failed to configure WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Set-WSLDistributionArchVersion {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [int]
        $Version
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Set architecture version '$Version' for WSL distribution '$DistributionName'")) {
        try {
            $wslArguments = @("--set-version", $DistributionName, $Version)
            Invoke-WSLCommand -Arguments $wslArguments | Out-Null
        } catch {
            throw "Failed to set architecture of WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Start-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]
        $DistributionName
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Start WSL distribution')) {
        $linuxCommand = "sleep infinity"
        Invoke-LinuxCommandInBackground -DistributionName $DistributionName -LinuxCommand $linuxCommand
        WaitFor-WSLDistributionState -DistributionName $DistributionName
    }
}


function Stop-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Stop WSL distribution')) {
        try {
            $wslArguments = @("--terminate", $DistributionName) # also remove Win32 running process
            Invoke-WSLCommand -Arguments $wslArguments | Out-Null
        } catch {
            throw "Failed to stop WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function WaitFor-WSLDistributionState {
    param(
        [string]
        $DistributionName,

        [int]
        # Default to 5 minutes (300 seconds)
        $TimeoutSeconds = 300,

        [string]
        $State = 'Running'
    )

    $startTime = Get-Date
    $timeout = New-TimeSpan -Seconds $TimeoutSeconds

    do {
        Start-Sleep -Seconds 2
        $distro = Get-WSLDistribution -DistributionName $DistributionName
        if ((Get-Date) - $startTime -gt $timeout) {
            throw "Timeout waiting for WSL distribution '$DistributionName' to have state '$State'."
        }
    } while ($distro.state -ne $State)
}


function Delete-WSLDistribution {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Delete (Unregister) WSL distribution')) {
        try {
            $wslArguments = @("--unregister", $DistributionName)
            Invoke-WSLCommand -Arguments $wslArguments | Out-Null
        } catch {
            throw "Failed to delete (unregister) WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


######################################### Main ##########################################


$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$web_download = $module.Params.web_download
$rootfs_path = $module.Params.rootfs_path
$rootfs_download_checksum = $module.Params.rootfs_download_checksum
$rootfs_download_checksum_algorithm = $module.Params.rootfs_download_checksum_algorithm
$rootfs_download_path = $module.Params.rootfs_download_path
$import_dir_path = $module.Params.import_dir_path
$import_bundle = $module.Params.import_bundle
$import_vhd = $module.Params.import_vhd
$arch_version = $module.Params.arch_version
$config = $module.Params.config
$state = $module.Params.state
$check_mode = $module.CheckMode

$config_path = "/etc/wsl.conf"

$before = Get-WSLDistribution -DistributionName $name -ConfigPath $config_path
$module.Diff.before = $before

try {
    if ($module.Diff.before -and $state -eq 'absent') {
        Delete-WSLDistribution -DistributionName $name -WhatIf:$check_mode
        Set-ModuleChanged -Module $module
        $module.ExitJson()
    }

    if (-not $module.Diff.before -and $state -eq 'absent') {
        $module.ExitJson()
    }

    if (-not $module.Diff.before) {
        # Install or import if not existed
        if ($rootfs_path) {
            if (-not $import_dir_path) {
                $import_dir_path = "$env:ProgramData\WSLDistributions\$name"
            }
            if (-not $rootfs_download_path) {
                $rootfs_download_path = "$([System.IO.Path]::GetTempPath())\WSLRootFSDownloaded"
            }
            $import_params = @{
                Module = $module
                DistributionName = $name
                RootFSPath = $rootfs_path
                RootFSDownloadChecksum = $rootfs_download_checksum
                RootFSDownloadChecksumAlgorithm = $rootfs_download_checksum_algorithm
                RootFSDownloadPath = $rootfs_download_path
                ImportBundle = $import_bundle
                ImportVHD = $import_vhd
                ImportDirectoryPath = $import_dir_path
                WhatIf = $check_mode
            }
            Import-WSLDistribution @import_params
        }
        else {
            $install_params = @{
                DistributionName = $name
                WebDownload = $web_download
                WhatIf = $check_mode
            }
            Install-WSLDistribution @install_params
        }

        Set-ModuleChanged -Module $module
    }

    $distro = Get-WSLDistribution -DistributionName $name -ConfigPath $config_path

    if ($config -and ($distro.config -replace '\s+', '') -ne ($config -replace '\s+', '')) {
        $config_params = @{
            DistributionName = $name
            ConfigPath = $config_path
            Config = $config
            WhatIf = $check_mode
        }
        Set-WSLDistributionConfig @config_params

        if ($distro.state -eq 'Running') {
            Stop-WSLDistribution -DistributionName $name -WhatIf:$check_mode
            Start-WSLDistribution -DistributionName $name -WhatIf:$check_mode
            if (-not $check_mode) {
                $module.Result.restarted = $true
            }
        } else {
            Stop-WSLDistribution -DistributionName $name -WhatIf:$check_mode
        }

        Set-ModuleChanged -Module $module
    }

    if ($arch_version -ne $distro.arch_version) {
        $set_version_params = @{
            DistributionName = $name
            Version = $arch_version
            WhatIf = $check_mode
        }
        Set-WSLDistributionArchVersion @set_version_params
        Set-ModuleChanged -Module $module
    }

    if ($state -eq 'stop' -and ('Stopped' -ne $before.state)) {
        Stop-WSLDistribution -DistributionName $name -WhatIf:$check_mode
        Set-ModuleChanged -Module $module
    }

    if ($state -eq 'run' -and ('Running' -ne $before.state)) {
        Start-WSLDistribution -DistributionName $name -WhatIf:$check_mode
        Set-ModuleChanged -Module $module
    }

    if ($module.Result.changed) {
        $module.Diff.after = Get-WSLDistribution -DistributionName $name -ConfigPath $config_path
    }

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()