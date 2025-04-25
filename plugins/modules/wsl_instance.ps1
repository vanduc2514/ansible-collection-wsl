#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Common
#AnsibleRequires -PowerShell ..module_utils.WSL
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.WebRequest

$spec = @{
    options = @{
        distribution = @{
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
        $DistributionName
    )

    # Get all available distributions
    $distributions = List-WSLDistribution

    if (-not $distributions) {
        return $null
    }

    foreach ($distro in $distributions) {
        # If the distro found in distributions
        if ($distro.name -eq $DistributionName) {
            return $distro
        }
    }

    return $null
}


function List-WSLDistribution {
    $wslDistros = Invoke-WSLCommand -Arguments @("--list", "--verbose")

    # Split the output into lines and remove empty lines
    # Skip the header line and process the remaining lines
    $lines = $wslDistros -split "\n" | Where-Object { $_ -ne '' } | Select-Object -Skip 1

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

function Get-WSLOnlineDistribution {
    $wslDistros = Invoke-WSLCommand -Arguments @("--list", "--online")

    # Split the output into lines and remove empty lines
    $lines = $wslDistros -split "\n" | Where-Object { $_ -ne '' }

    # Create an array to store the distribution information
    $distributions = @()

    # Flag to indicate when we've found the header line
    $headerFound = $false

    foreach ($line in $lines) {
        # Skip lines until we find "NAME"
        if ($line -match "NAME\s+FRIENDLY NAME") {
            $headerFound = $true
            continue
        }

        # Process distribution entries after the header
        if ($headerFound -and -not [string]::IsNullOrWhiteSpace($line)) {
            # The name is everything before the first space
            $name = ($line -split '\s+', 2)[0]
            $friendlyName = ($line -split '\s+', 2)[1]
            if ($name) {
                $distro = [PSCustomObject]@{
                    name = $name
                    friendly_name = $friendlyName
                }
                $distributions += $distro
            }
        }
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

    $availableDistros = Get-WSLOnlineDistribution
    $availableNames = $availableDistros | ForEach-Object { $_.name }
    if (-not ($availableNames -contains $DistributionName)) {
        throw "WSL distribution '$DistributionName' is not available for online installation. Available distributions: $($availableNames -join ', ')"
    }

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

        [bool]
        $RootFSDownload,

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

    $extraArgument = @() + $(
        if ($ImportVHD) { '--vhd' }
    ) -join ' '

    # If the path is an URL, handle download
    if ($RootFSDownload -and $PSCmdlet.ShouldProcess($DistributionName, 'Download WSL distribution')) {
        $rootfsDownloadScript = {
            param($Response, $Stream)

            $rootFSDownloadParentPath = Split-Path -Path $RootFSDownloadPath -Parent
            if (-not (Test-Path -Path $rootFSDownloadParentPath)) {
                New-Item -ItemType Directory -Path $rootFSDownloadParentPath -Force | Out-Null
            }

            $rootfs = [System.IO.File]::Create($RootFSDownloadPath)

            try {
                $Stream.CopyTo($rootfs)
                $rootfs.Flush()
            }
            finally {
                $rootfs.Dispose()
            }

            if ($RootFSDownloadChecksum) {
                $getFileHashArgument = @{
                    Path = $RootFSDownloadPath
                    Algorithm = $RootFSDownloadChecksumAlgorithm
                }
                $downloadedChecksum = (Get-FileHash @getFileHashArgument).Hash.toLower()
                if ($downloadedChecksum -ne $RootFSDownloadChecksum) {
                    Remove-Item -Path $RootFSDownloadPath -Force | Out-Null
                    throw "Failed Checksum ($RootFSDownloadChecksumAlgorithm) Check for download rootfs, '$downloadedChecksum' did not match '$RootFSDownloadChecksum'"
                }
            }
        }

        if (-not $(Test-Path -Path $RootFSDownloadPath)) {
            $webRequest = Get-AnsibleWindowsWebRequest -Uri $RootFSPath

            try {
                Invoke-AnsibleWindowsWebRequest -Module $Module -Request $webRequest -Script $rootfsDownloadScript
            }
            catch {
                throw "Failed to download rootfs from '$RootFSPath': $($_.Exception.Message)"
            }
        }

        # If the URL points to a Appx bundle, extract it and get the rootfs inside
        if ($ImportBundle -and $PSCmdlet.ShouldProcess($DistributionName, 'Extract WSL distribution bundle')) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($RootFSDownloadPath)
            $rootfsDownloadPathParent = Split-Path -Path $RootFSDownloadPath -Parent
            $rootfsExtractDir = Join-Path -Path $rootfsDownloadPathParent -ChildPath $baseName

            try {
                $expandParams = @{
                    Path = $RootFSDownloadPath
                    DestinationPath = $rootfsExtractDir
                    Force = $true
                    ErrorAction = 'Stop'
                }
                Expand-Archive @expandParams
            } catch {
                throw "Failed to extract rootfs bundle from '$RootFSDownloadPath': $($_.Exception.Message)"
            }

            $rootfsExtracted = Get-ChildItem -Path $rootfsExtractDir -Recurse |
                Where-Object { $_.Name -match '\.tar(\.gz)?$' } |
                Select-Object -First 1
            if (-not $rootfsExtracted) {
                throw "Failed to find rootfs file in the extracted bundle for WSL distribution: $DistributionName"
            }

            $RootFSPath = $rootfsExtracted.FullName
        }
        else {
            $RootFSPath = $RootFSDownloadPath
        }
    }

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Import WSL distribution')) {
        try {
            $wslArguments = @(
                "--import", $DistributionName,
                $ImportDirectoryPath, $RootFSPath
                $extraArgument
            )
            Invoke-WSLCommand -Arguments $wslArguments | Out-Null
        } catch {
            throw "Failed to import WSL distribution '$DistributionName': $($_.Exception.Message)"
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

$distribution = $module.Params.distribution
$web_download = $module.Params.web_download
$rootfs_path = $module.Params.rootfs_path
$rootfs_download_checksum = $module.Params.rootfs_download_checksum
$rootfs_download_checksum_algorithm = $module.Params.rootfs_download_checksum_algorithm
$rootfs_download_path = $module.Params.rootfs_download_path
$import_dir_path = $module.Params.import_dir_path
$import_bundle = $module.Params.import_bundle
$import_vhd = $module.Params.import_vhd
$arch_version = $module.Params.arch_version
$state = $module.Params.state
$check_mode = $module.CheckMode

$rootfs_download = $rootfs_path -and $rootfs_path.StartsWith('http')

$rootfs_download_path = if ($rootfs_download_path) {
    $rootfs_download_path
} elseif ($rootfs_download) {
    $urlHash = Get-HashFromURL -Url $rootfs_path
    $fileExtension = if ($import_bundle) { "zip" } else { "tar.gz" }
    "$([System.IO.Path]::GetTempPath())\WSLRootFSDownloaded\${urlHash}.${fileExtension}"
}

$import_dir_path = if ($import_dir_path) {
    $import_dir_path
} else {
    "$env:ProgramData\WSLDistributions\$distribution"
}

$before = Get-WSLDistribution -DistributionName $distribution
$module.Diff.before = $before

try {
    if ($state -eq 'absent') {
        if ($before) {
            Delete-WSLDistribution -DistributionName $distribution -WhatIf:$check_mode
            Set-ModuleChanged -Module $module
            $module.Diff.after = $null
        }
        $module.ExitJson()
    }

    if (-not $module.Diff.before) {
        # Install or import if not existed
        if ($rootfs_path) {
            $import_params = @{
                Module = $module
                DistributionName = $distribution
                RootFSPath = $rootfs_path
                RootFSDownload = $rootfs_download
                RootFSDownloadPath = $rootfs_download_path
                RootFSDownloadChecksum = $rootfs_download_checksum
                RootFSDownloadChecksumAlgorithm = $rootfs_download_checksum_algorithm
                ImportBundle = $import_bundle
                ImportVHD = $import_vhd
                ImportDirectoryPath = $import_dir_path
                WhatIf = $check_mode
            }
            Import-WSLDistribution @import_params
        }
        else {
            $install_params = @{
                DistributionName = $distribution
                WebDownload = $web_download
                WhatIf = $check_mode
            }
            Install-WSLDistribution @install_params
        }

        Set-ModuleChanged -Module $module
    }

    $distro = Get-WSLDistribution -DistributionName $distribution

    if ($arch_version -ne $distro.arch_version) {
        $set_version_params = @{
            DistributionName = $distribution
            Version = $arch_version
            WhatIf = $check_mode
        }
        Set-WSLDistributionArchVersion @set_version_params
        Set-ModuleChanged -Module $module
    }

    if ($state -eq 'stop' -and ('Stopped' -ne $before.state)) {
        Stop-WSLDistribution -DistributionName $distribution -WhatIf:$check_mode
        Set-ModuleChanged -Module $module
    }

    if ($state -eq 'run' -and ('Running' -ne $before.state)) {
        Start-WSLDistribution -DistributionName $distribution -WhatIf:$check_mode
        Set-ModuleChanged -Module $module
    }

    if ($module.Result.changed) {
        $module.Diff.after = Get-WSLDistribution -DistributionName $distribution
    }

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
