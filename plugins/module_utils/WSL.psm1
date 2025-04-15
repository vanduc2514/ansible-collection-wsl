#AnsibleRequires -PowerShell Common

function Test-WSLFileExist {
    [OutputType([bool])]
    param(
        [string]
        $DistributionName,

        [string]
        $Path
    )

    $invokeLinuxCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        # -e flag checks if the file exists regardless of type
        LinuxCommand = "test -e '$Path' && echo 'true' || echo 'false'"
    }

    $result = Invoke-LinuxCommand @invokeLinuxCommandArguments

    return [System.Convert]::ToBoolean($result.Trim())
}

function Get-WSLFileContent {
    [OutputType([string])]
    param(
        [string]
        $DistributionName,

        [string]
        $Path
    )

    $invokeLinuxCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = "cat $Path 2>/dev/null || true"
    }

    return Invoke-LinuxCommand @invokeLinuxCommandArguments
}

function New-WSLDirectory {
    param(
        [string]
        $DistributionName,

        [string]
        $Owner,

        [string]
        $Mode,

        [string]
        $Path
    )

    $createDirectoryCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = "mkdir --parents $Path"
    }

    Invoke-LinuxCommand @createDirectoryCommandArguments

    $setOwnerAndModeCommandArguments = @{
        DistributionName = $DistributionName
        Owner = $Owner
        Mode = $Mode
        Path = $Path
    }

    Set-OwnerAndModeWSLFile @setOwnerAndModeCommandArguments
}

function New-WSLFile {
    param(
        [string]
        $DistributionName,

        [string]
        $Owner,

        [string]
        $Mode,

        [string]
        $Path
    )

    $touchNewFileCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = "touch $Path"
    }

    Invoke-LinuxCommand @touchNewFileCommandArguments

    $setOwnerAndModeCommandArguments = @{
        DistributionName = $DistributionName
        Owner = $Owner
        Mode = $Mode
        Path = $Path
    }

    Set-OwnerAndModeWSLFile @setOwnerAndModeCommandArguments
}


function Set-OwnerAndModeWSLFile {
    param(
        [string]
        $DistributionName,

        [string]
        $Owner,

        [string]
        $Mode,

        [string]
        $Path
    )

    $changeOwnerCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = "chown --recursive $Owner $Path"
    }

    Invoke-LinuxCommand @changeOwnerCommandArguments

    $changeModeCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = "chmod --recursive $Mode $Path"
    }

    Invoke-LinuxCommand @changeModeCommandArguments
}

function Set-WSLFileContent {
    param(
        [string]
        $DistributionName,

        [bool]
        $Append = $false,

        [string]
        $Content,

        [string]
        $Path
    )

    # Convert content to base64 to safely handle multiline strings and special characters
    $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $base64Content = [Convert]::ToBase64String($contentBytes)

    $linuxCommand = if ($Append) {
        "echo '$base64Content' | base64 -d >> $Path"
    } else {
        "echo '$base64Content' | base64 -d > $Path"
    }

    $setContentCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = $linuxCommand
    }

    Invoke-LinuxCommand @setContentCommandArguments
}

function Remove-WSLFile {
    param(
        [string]
        $DistributionName,

        [bool]
        $Recursive = $true,

        [bool]
        $Force = $false,

        [string]
        $Path
    )

    $removeCommand = "rm"

    $extraArguments = @() + $(
        if ($Recursive) { '--recursive' }
        if ($Force) { '--force' }
    ) -join ' '

    $invokeLinuxCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = "$removeCommand $extraArguments $Path"
    }

    Invoke-LinuxCommand @invokeLinuxCommandArguments
}

function Invoke-WSLCommand {
    param(
        [string[]]
        $Arguments
    )

    return wsl @Arguments | Out-String | Get-FormattedText | Test-CommandOutput
}

function Invoke-WSLCommandInBackground {
    param(
        [string]
        $Argument
    )

    $proc = New-Win32Process -CommandLine "wsl $Argument"
    if ($proc.ReturnValue -ne 0) {
        throw "Failed to invoke WSL command in win32 process for distribution '$DistributionName'."
    }

    return $proc
}

function Invoke-LinuxCommand {
    [OutputType([string])]
    param(
        [string]
        $DistributionName,

        [string]
        $DistributionUser = "root",

        [string[]]
        $Shell = @("/bin/sh", "-c"),

        [string]
        $LinuxCommand
    )

    $wslArguments = @(
        "--distribution", $DistributionName,
        "--user", $DistributionUser,
        "--"
    ) + $Shell + @("`"$LinuxCommand`"")

    return Invoke-WSLCommand -Arguments $wslArguments
}

function Invoke-LinuxCommandInBackground {
    [OutputType([string])]
    param(
        [string]
        $DistributionName,

        [string]
        $DistributionUser = "root",

        [string]
        $Shell = "/bin/sh -c",

        [string]
        $LinuxCommand
    )

    $wslArgument = "--distribution $DistributionName --user $DistributionUser -- $Shell `"$LinuxCommand`""
    return Invoke-WSLCommandInBackground -Argument $wslArgument
}

function Test-CommandOutput {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [string]
        $CommandOutput
    )

    if ($CommandOutput -match 'Error Code') {
        throw $CommandOutput
    }

    return $CommandOutput
}

$export_members = @{
    Function = @(
        'Test-WSLFileExist',
        'Get-WSLFileContent',
        'New-WSLDirectory',
        'New-WSLFile',
        'Set-WSLFileContent',
        'Set-OwnerAndModeWSLFile',
        'Remove-WSLFileContent',
        'Invoke-WSLCommand',
        'Invoke-WSLCommandInBackground',
        'Invoke-LinuxCommand',
        'Invoke-LinuxCommandInBackground'
    )
}
Export-ModuleMember @export_members
