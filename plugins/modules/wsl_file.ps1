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
        path = @{
            type     = "str"
            required = $true
        }
        content = @{
            type     = "str"
            required = $false
        }
        append = @{
            type     = "bool"
            default  = $false
        }
        recursive = @{
            type     = "bool"
            default  = $true
        }
        force = @{
            type     = "bool"
            default  = $false
        }
        owner = @{
            type     = "str"
            required = $false
        }
        mode = @{
            type     = "str"
            required = $false
        }
        state = @{
            type     = "str"
            choices  = @("file", "directory", "absent")
            default  = "file"
        }
    }
    supports_check_mode = $true
}


function Get-FileInfo {
    param(
        [string]
        $DistributionName,

        [string]
        $Path
    )

    if (-not $(Test-WSLFileExist -DistributionName $DistributionName -Path $Path)) {
        return $null
    }

    # Check if it's a directory
    $isDirectoryCmd = "test -d '$Path' && echo 'true' || echo 'false'"
    $isDirectory = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $isDirectoryCmd).Trim() -eq "true"

    # Get owner
    $ownerCmd = "stat -c '%U' '$Path' 2>/dev/null || echo ''"
    $owner = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $ownerCmd).Trim()

    # Get mode
    $modeCmd = "stat -c '%a' '$Path' 2>/dev/null || echo ''"
    $mode = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $modeCmd).Trim()

    # Get content if it's a file
    $content = if (-not $isDirectory) {
        Get-WSLFileContent -DistributionName $DistributionName -Path $Path
    } else {
        $null
    }

    return @{
        path = $Path
        is_directory = $isDirectory
        owner = $owner
        mode = $mode
        content = $content
    }
}


function Remove-WSLFileOrDirectory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [bool]
        $Recursive = $false,

        [bool]
        $Force = $false
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Remove $Path")) {
        try {
            $removeWSLFileParams = @{
                DistributionName = $DistributionName
                Recursive = $Recursive
                Force = $Force
                Path = $Path
            }
            Remove-WSLFile @removeWSLFileParams
        } catch {
            throw "Failed to remove '$Path' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function New-WSLEmptyFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [string]
        $Owner,

        [string]
        $Mode
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create empty file: $Path")) {
        try {
            $newWSLFileParams = @{
                DistributionName = $DistributionName
                Path = $Path
                Owner = $Owner
                Mode = $Mode
            }
            New-WSLFile @newWSLFileParams
        } catch {
            throw "Failed to create empty file '$Path' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Set-WSLFileContents {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [string]
        $Content,

        [bool]
        $Append = $false
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Set content for file: $Path")) {
        try {
            $setWSLFileContentParams = @{
                DistributionName = $DistributionName
                Content = $Content
                Append = $Append
                Path = $Path
            }
            Set-WSLFileContent @setWSLFileContentParams
        } catch {
            throw "Failed to set content for file '$Path' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Update-WSLFileAttributes {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [string]
        $Owner,

        [string]
        $Mode,

        [bool]
        $Recursive = $false
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Update attributes for: $Path")) {
        try {
            if ($Owner -or $Mode) {
                $setOwnerAndModeParams = @{
                    DistributionName = $DistributionName
                    Path = $Path
                    Recursive = $Recursive
                }

                if ($Owner) {
                    $setOwnerAndModeParams.Owner = $Owner
                }

                if ($Mode) {
                    $setOwnerAndModeParams.Mode = $Mode
                }

                Set-OwnerAndModeWSLFile @setOwnerAndModeParams
            }
        } catch {
            throw "Failed to update attributes for '$Path' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function New-WSLDirectoryStructure {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [string]
        $Owner,

        [string]
        $Mode,

        [bool]
        $Recursive = $true
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create directory: $Path")) {
        try {
            $newWSLDirectoryParams = @{
                DistributionName = $DistributionName
                Path = $Path
                Owner = $Owner
                Mode = $Mode
                Recursive = $Recursive
            }
            New-WSLDirectory @newWSLDirectoryParams
        } catch {
            throw "Failed to create directory '$Path' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Test-FileContentChanged {
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [string]
        $Content,

        [bool]
        $Append = $false
    )

    $existingContent = Get-WSLFileContent -DistributionName $DistributionName -Path $Path

    if ($Append) {
        return -not $existingContent.Contains($Content)
    } else {
        return $existingContent -ne $Content
    }
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution_name = $module.Params.distribution
$path = $module.Params.path
$content = $module.Params.content
$append = $module.Params.append
$recursive = $module.Params.recursive
$force = $module.Params.force
$owner = $module.Params.owner
$mode = $module.Params.mode
$state = $module.Params.state
$check_mode = $module.CheckMode

$owner = if ($owner) {
    $owner
} else {
    'root'
}
# default rw for file and rwx for directory
$mode = if ($mode) {
    $mode
} elseif ($state -eq 'file') {
    '644'
} elseif ($state -eq 'directory') {
    '755'
} else {
    $null
}

try {
    if ($state -eq 'directory' -and $content) {
        $module.FailJson("Cannot set content when state is 'directory'")
    }

    # Get current file information
    $file_info = Get-FileInfo -DistributionName $distribution_name -Path $path
    $module.Diff.before = $file_info

    $invalidFileChange = $state -eq 'file' -and $file_info.is_directory
    $invalidDirectoryChange = $state -eq 'directory' -and -not $file_info.is_directory
    if ($file_info) {
        if ($invalidFileChange) {
            $module.FailJson("Invalid state. Cannot change from directory to file")
        }
        if ($invalidDirectoryChange) {
            $module.FailJson("Invalid state. Cannot change from file to directory")
        }
    }

    if ($state -eq 'absent') {
        if ($file_info) {
            $removeWSLFileOrDirectoryParams = @{
                DistributionName = $distribution_name
                Path = $path
                Recursive = $recursive
                Force = $force
                WhatIf = $check_mode
            }

            Remove-WSLFileOrDirectory @removeWSLFileOrDirectoryParams
            Set-ModuleChanged -Module $module
            $module.Diff.after = $null
        }

        $module.Result.path = $null
        $module.ExitJson()
    }

    if ($state -eq 'file') {
        if (-not $file_info) {
            $newWSLEmptyFileParams = @{
                DistributionName = $distribution_name
                Path = $path
                Owner = $owner
                Mode = $mode
                WhatIf = $check_mode
            }
            New-WSLEmptyFile @newWSLEmptyFileParams
            Set-ModuleChanged -Module $module
            $file_info = Get-FileInfo -DistributionName $distribution_name -Path $path
        }

        $contentChangedParams = @{
            DistributionName = $distribution_name
            Path = $path
            Content = $content
            Append = $append
        }
        if ($content -and $(Test-FileContentChanged @contentChangedParams)) {
            $setWSLFileContentsParams = @{
                DistributionName = $distribution_name
                Path = $path
                Content = $content
                Append = $append
                WhatIf = $check_mode
            }
            Set-WSLFileContents @setWSLFileContentsParams
            Set-ModuleChanged -Module $module
        }
    }

    if ($state -eq 'directory' -and -not $file_info) {
        $newWSLDirectoryStructureParams = @{
            DistributionName = $distribution_name
            Path = $path
            Owner = $owner
            Mode = $mode
            Recursive = $recursive
            WhatIf = $check_mode
        }

        New-WSLDirectoryStructure @newWSLDirectoryStructureParams
        Set-ModuleChanged -Module $module
        $file_info = Get-FileInfo -DistributionName $distribution_name -Path $path
    }

    $ownerChanged = $owner -and $file_info.owner -ne $owner
    $modeChanged = $mode -and $file_info.mode -ne $mode
    if ($ownerChanged -or $modeChanged) {
        $updateWSLFileAttributesParams = @{
            DistributionName = $distribution_name
            Path = $path
            Owner = $owner
            Mode = $mode
            Recursive = $recursive
            WhatIf = $check_mode
        }
        Update-WSLFileAttributes @updateWSLFileAttributesParams
        Set-ModuleChanged -Module $module
    }

    # Update diff after
    $module.Diff.after = Get-FileInfo -DistributionName $distribution_name -Path $path

    # Module outputs
    $module.Result.path = $path
    $module.Result.file_info = $module.Diff.after

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()