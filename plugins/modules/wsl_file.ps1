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
    mutually_exclusive = @(
        , @("state=directory", "content")
    )
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
        exists = $true
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

function Get-ParentDirectory {
    param(
        [string]
        $Path
    )

    return [System.IO.Path]::GetDirectoryName($Path)
}

function New-WSLEmptyFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [string]
        $Owner = "root",

        [string]
        $Mode = "644"
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create empty file: $Path")) {
        try {
            # Ensure parent directory exists
            $parent = Get-ParentDirectory -Path $Path
            if (-not $(Test-WSLFileExist -DistributionName $DistributionName -Path $parent)) {
                $newWSLDirectoryParams = @{
                    DistributionName = $DistributionName
                    Path = $parent
                    Owner = $Owner
                    Mode = "755" # Default directory mode
                    Recursive = $true
                }
                New-WSLDirectory @newWSLDirectoryParams
            }

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
            # If appending, check if content is already in the file
            if ($Append) {
                $existingContent = Get-WSLFileContent -DistributionName $DistributionName -Path $Path
                if ($existingContent -and $existingContent.Contains($Content)) {
                    # Content already exists, no need to append
                    return
                }
            }

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
        $Owner = "root",

        [string]
        $Mode = "755",

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

    $fileExists = Test-WSLFileExist -DistributionName $DistributionName -Path $Path

    if (-not $fileExists) {
        return $true
    }

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

try {
    # Validate parameters
    if ($state -eq "directory" -and $content) {
        $module.FailJson("Cannot set content when state is 'directory'")
    }

    # Get current file information
    $file_info = Get-FileInfo -DistributionName $distribution_name -Path $path
    $module.Diff.before = $file_info

    # Handle state=absent
    if ($state -eq "absent") {
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

        # Module outputs
        $module.Result.path = $path
        $module.ExitJson()
    }

    # Handle state=file
    if ($state -eq "file") {
        $contentChanged = $false
        $fileNeedsCreation = (-not $file_info) -or ($file_info -and $file_info.is_directory)
        $ownerChanged = $owner -and $file_info -and $file_info.owner -ne $owner
        $modeChanged = $mode -and $file_info -and $file_info.mode -ne $mode

        if ($fileNeedsCreation) {
            $newWSLEmptyFileParams = @{
                DistributionName = $distribution_name
                Path = $path
                Owner = if ($owner) { $owner } else { "root" }
                Mode = if ($mode) { $mode } else { "644" }
                WhatIf = $check_mode
            }
            New-WSLEmptyFile @newWSLEmptyFileParams
            Set-ModuleChanged -Module $module
        }

        if ($content -and ($fileNeedsCreation -or (Test-FileContentChanged -DistributionName $distribution_name -Path $path -Content $content -Append $append))) {
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

        if ((-not $fileNeedsCreation) -and ($ownerChanged -or $modeChanged)) {
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
    }

    # Handle state=directory
    if ($state -eq "directory") {
        $dirExists = $file_info -and $file_info.is_directory
        $ownerChanged = $owner -and $file_info -and $file_info.owner -ne $owner
        $modeChanged = $mode -and $file_info -and $file_info.mode -ne $mode

        if (-not $dirExists -or $ownerChanged -or $modeChanged) {
            $newWSLDirectoryStructureParams = @{
                DistributionName = $distribution_name
                Path = $path
                Owner = if ($owner) { $owner } else { "root" }
                Mode = if ($mode) { $mode } else { "755" }
                Recursive = $recursive
                WhatIf = $check_mode
            }

            New-WSLDirectoryStructure @newWSLDirectoryStructureParams
            Set-ModuleChanged -Module $module
        }
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