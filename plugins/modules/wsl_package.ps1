#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Common
#AnsibleRequires -PowerShell ..module_utils.WSL

$spec = @{
    options = @{
        distribution = @{
            type     = "str"
            required = $true
        }
        name = @{
            type     = "str"
            required = $true
        }
        version = @{
            type     = "str"
            required = $false
        }
        force = @{
            type     = "bool"
            default  = $false
        }
        update_cache = @{
            type     = "bool"
            default  = $false
        }
        state = @{
            type     = "str"
            choices  = @("present", "absent")
            default  = "present"
        }
    }
    supports_check_mode = $true
}


function Get-PackageManager {
    param(
        [string]
        $DistributionName
    )

    $detectPackageManagerCommand = @'
if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
elif command -v yum >/dev/null 2>&1; then
    echo "yum"
elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
elif command -v apk >/dev/null 2>&1; then
    echo "apk"
else
    echo "unknown"
fi
'@

    $linuxCommandParams = @{
        DistributionName = $DistributionName
        LinuxCommand     = $detectPackageManagerCommand
    }
    $packageManager = (Invoke-LinuxCommand @linuxCommandParams).Trim()

    if ($packageManager -eq "unknown") {
        throw "Could not determine package manager for distribution '$DistributionName'"
    }

    return $packageManager
}


function Get-PackageInfo {
    param(
        [string]
        $DistributionName,

        [string]
        $PackageName,

        [string]
        $PackageManager
    )

    try {
        $getPackageCommand = switch ($PackageManager) {
            "apt" { "dpkg-query -s $PackageName 2>/dev/null | grep -E '^Status:|^Version:' || echo 'not-installed'" }
            "dnf" { "rpm -q --queryformat '%{NAME} %{VERSION}-%{RELEASE}' $PackageName 2>/dev/null || echo 'not-installed'" }
            "yum" { "rpm -q --queryformat '%{NAME} %{VERSION}-%{RELEASE}' $PackageName 2>/dev/null || echo 'not-installed'" }
            "zypper" { "rpm -q --queryformat '%{NAME} %{VERSION}-%{RELEASE}' $PackageName 2>/dev/null || echo 'not-installed'" }
            "pacman" { "pacman -Q $PackageName 2>/dev/null || echo 'not-installed'" }
            "apk" { "apk version $PackageName 2>/dev/null || echo 'not-installed'" }
            default { throw "Unsupported package manager: $PackageManager" }
        }

        $linuxCommandParams = @{
            DistributionName = $DistributionName
            DistributionUser = 'root'
            LinuxCommand     = $getPackageCommand
        }
        $result = (Invoke-LinuxCommand @linuxCommandParams).Trim()

        $installed = switch ($PackageManager) {
            "apk" {
                # For APK, check if there's any content after "Installed: Available:"
                $result -match "$PackageName-[^\s]+"
            }
            default {
                -not ($result -match "not-installed" -or
                    $result -match "no packages found" -or
                    $result -match "not installed")
            }
        }

        # Extract the version based on package manager
        $version = switch ($PackageManager) {
            "apt" { if ($result -match "Version: (.+)$") { $Matches[1] } else { $null } }
            "dnf" { if ($result -match "$PackageName (.+)$") { $Matches[1] } else { $null } }
            "yum" { if ($result -match "$PackageName (.+)$") { $Matches[1] } else { $null } }
            "zypper" { if ($result -match "$PackageName (.+)$") { $Matches[1] } else { $null } }
            "pacman" { if ($result -match "$PackageName (.+)$") { $Matches[1] } else { $null } }
            "apk" { if ($result -match "$PackageName-([^\s]+)") { $Matches[1] } else { $null } }
            default { $null }
        }

        return @{
            installed = $installed
            version = $version
        }
    }
    catch {
        throw "Failed to get package info for '$PackageName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
    }
}


function Update-PackageCache {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $PackageManager
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, 'Update package cache')) {
        try {
            $updateCacheCommand = switch ($PackageManager) {
                "apt" { "apt-get update > /dev/null" }
                "dnf" { "LC_ALL=C.UTF-8 dnf update -y -q > /dev/null" }
                "yum" { "LC_ALL=C.UTF-8 yum update -y -q > /dev/null" }
                "zypper" { "LC_ALL=C.UTF-8 zypper refresh" }
                "pacman" { "pacman -Sy" }
                "apk" { "apk update" }
                default { throw "Unsupported package manager: $PackageManager" }
            }

            $updateCacheCommandArguments = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = $updateCacheCommand
            }

            Invoke-LinuxCommand @updateCacheCommandArguments | Out-Null
        }
        catch {
            throw "Failed to update package cache in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Install-Package {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $PackageName,

        [string]
        $PackageVersion,

        [string]
        $PackageManager,

        [bool]
        $Force = $false
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Install package: $PackageName")) {
        try {
            $packageSpec = if ($PackageVersion) {
                switch ($PackageManager) {
                    "apt" { "$PackageName=$PackageVersion" }
                    "dnf" { "$PackageName-$PackageVersion" }
                    "yum" { "$PackageName-$PackageVersion" }
                    "zypper" { "$PackageName=$PackageVersion" }
                    "pacman" { "$PackageName=$PackageVersion" }
                    "apk" { "$PackageName=$PackageVersion" }
                    default { throw "Unsupported package manager: $PackageManager" }
                }
            } else {
                $PackageName
            }

            $forceFlag = if ($Force) {
                switch ($PackageManager) {
                    "apt" { "-y --allow-downgrades --allow-change-held-packages --fix-broken" }
                    "dnf" { "-y" }
                    "yum" { "-y" }
                    "zypper" { "-y --force" }
                    "pacman" { "--noconfirm --needed" }
                    "apk" { "--no-cache" }
                    default { "" }
                }
            } else {
                switch ($PackageManager) {
                    "apt" { "-y" }
                    "dnf" { "-y" }
                    "yum" { "-y" }
                    "zypper" { "-y" }
                    "pacman" { "--noconfirm" }
                    "apk" { "" }
                    default { "" }
                }
            }

            $installCommand = switch ($PackageManager) {
                "apt" {
                    "DEBIAN_FRONTEND=noninteractive " + `
                    "DEBCONF_NONINTERACTIVE_SEEN=true " + `
                    "apt-get install -qq $forceFlag $packageSpec"
                }
                "dnf" { "LC_ALL=C.UTF-8 dnf install $forceFlag $packageSpec -q > /dev/null" }
                "yum" { "LC_ALL=C.UTF-8 yum install $forceFlag $packageSpec -q > /dev/null" }
                "zypper" { "LC_ALL=C.UTF-8 zypper install $forceFlag $packageSpec" }
                "pacman" { "pacman -S $forceFlag $packageSpec" }
                "apk" { "apk add $forceFlag $packageSpec" }
                default { throw "Unsupported package manager: $PackageManager" }
            }

            $installCommandArguments = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = $installCommand
            }

            Invoke-LinuxCommand @installCommandArguments | Out-Null
        } catch {
            throw "Failed to install package '$PackageName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Remove-Package {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $PackageName,

        [string]
        $PackageManager,

        [bool]
        $Force = $false
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Remove package: $PackageName")) {
        try {
            $forceFlag = if ($Force) {
                switch ($PackageManager) {
                    "apt" { "-y --alow" }
                    "dnf" { "-y" }
                    "yum" { "-y" }
                    "zypper" { "-y --force" }
                    "pacman" { "--noconfirm" }
                    "apk" { "--force-broken-world" }
                    default { "" }
                }
            } else {
                switch ($PackageManager) {
                    "apt" { "-y" }
                    "dnf" { "-y" }
                    "yum" { "-y" }
                    "zypper" { "-y" }
                    "pacman" { "--noconfirm" }
                    "apk" { "" }
                    default { "" }
                }
            }

            $removeCommand = switch ($PackageManager) {
                "apt" { "apt-get remove $forceFlag $PackageName" }
                "dnf" { "LC_ALL=C.UTF-8 dnf remove $forceFlag $PackageName" }
                "yum" { "LC_ALL=C.UTF-8 yum remove $forceFlag $PackageName" }
                "zypper" { "LC_ALL=C.UTF-8 zypper remove $forceFlag $PackageName" }
                "pacman" { "pacman -R $forceFlag $PackageName" }
                "apk" { "apk del $forceFlag $PackageName" }
                default { throw "Unsupported package manager: $PackageManager" }
            }

            $removeCommandArguments = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = $removeCommand
            }

            Invoke-LinuxCommand @removeCommandArguments | Out-Null
        }
        catch {
            throw "Failed to remove package '$PackageName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution_name = $module.Params.distribution
$package_name = $module.Params.name
$package_version = $module.Params.version
$force = $module.Params.force
$update_cache = $module.Params.update_cache
$state = $module.Params.state
$check_mode = $module.CheckMode

try {
    $package_manager = Get-PackageManager -DistributionName $distribution_name

    $packageInfoParams = @{
        DistributionName = $distribution_name
        PackageName      = $package_name
        PackageManager   = $package_manager
    }
    $package_info = Get-PackageInfo @packageInfoParams
    $module.Diff.before = $package_info

    if ($update_cache) {
        $updatePackageCacheParams = @{
            DistributionName = $distribution_name
            PackageManager = $package_manager
            WhatIf = $check_mode
        }

        Update-PackageCache @updatePackageCacheParams
    }

    if ($state -eq 'absent') {
        if ($package_info.installed) {
            $removePackageParams = @{
                DistributionName = $distribution_name
                PackageName = $package_name
                PackageManager = $package_manager
                Force = $force
                WhatIf = $check_mode
            }

            Remove-Package @removePackageParams
            Set-ModuleChanged -Module $module
        }
    } elseif ($state -eq 'present') {
        $need_to_install = -not $package_info.installed
        $need_to_upgrade = $package_info.installed -and $package_version -and ($package_info.version -ne $package_version)

        if ($need_to_install -or $need_to_upgrade) {
            $installPackageParams = @{
                DistributionName = $distribution_name
                PackageName = $package_name
                PackageVersion = $package_version
                PackageManager = $package_manager
                Force = $force
                WhatIf = $check_mode
            }

            Install-Package @installPackageParams
            Set-ModuleChanged -Module $module
        }
    }

    $package_info = Get-PackageInfo @packageInfoParams
    $module.Diff.after = $package_info

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
