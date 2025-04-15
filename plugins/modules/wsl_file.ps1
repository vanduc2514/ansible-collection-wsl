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
            default  = $false
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

function New-WSLFileWithContent {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Path,

        [string]
        $Content,

        [bool]
        $Append = $false,

        [string]
        $Owner,

        [string]
        $Mode
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create file: $Path")) {
        try {
            # Ensure parent directory exists
            $parent = Get-ParentDirectory -Path $Path
            if (-not $(Test-WSLFileExist -DistributionName $DistributionName -Path $parent)) {
                $newWSLDirectoryParams = @{
                    DistributionName = $DistributionName
                    Path = $parent
                    Owner = if ($Owner) { $Owner } else { "root" }
                    Mode = if ($Mode) { $Mode } else { "755" }
                }
                New-WSLDirectory @newWSLDirectoryParams
            }

            # Create file if it doesn't exist
            if (-not $(Test-WSLFileExist -DistributionName $DistributionName -Path $Path)) {
                $newWSLFileParams = @{
                    DistributionName = $DistributionName
                    Path = $Path
                    Owner = if ($Owner) { $Owner } else { "root" }
                    Mode = if ($Mode) { $Mode } else { "644" }
                }
                New-WSLFile @newWSLFileParams
            }

            # Set content if provided
            if ($Content) {
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
            }

            # Set owner and mode if specified
            if ($Owner -or $Mode) {
                $setOwnerAndModeParams = @{
                    DistributionName = $DistributionName
                    Path = $Path
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
            throw "Failed to create file '$Path' in WSL distribution '$DistributionName': $($_.Exception.Message)"
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
        $Mode
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create directory: $Path")) {
        try {
            $newWSLDirectoryParams = @{
                DistributionName = $DistributionName
                Path = $Path
                Owner = if ($Owner) { $Owner } else { "root" }
                Mode = if ($Mode) { $Mode } else { "755" }
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

    if ($recursive -and $state -ne "absent") {
        $module.FailJson("'recursive' parameter can only be used when state is 'absent'")
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

        if ($content -or -not $file_info -or ($file_info -and $file_info.is_directory)) {
            $contentChanged = Test-FileContentChanged -DistributionName $distribution_name -Path $path -Content $content -Append $append
        }

        $ownerChanged = $owner -and $file_info -and $file_info.owner -ne $owner
        $modeChanged = $mode -and $file_info -and $file_info.mode -ne $mode

        if (-not $file_info -or $file_info.is_directory -or $contentChanged -or $ownerChanged -or $modeChanged) {
            $newWSLFileWithContentParams = @{
                DistributionName = $distribution_name
                Path = $path
                Content = $content
                Append = $append
                Owner = $owner
                Mode = $mode
                WhatIf = $check_mode
            }

            New-WSLFileWithContent @newWSLFileWithContentParams
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
                Owner = $owner
                Mode = $mode
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