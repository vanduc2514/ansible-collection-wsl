#AnsibleRequires -PowerShell Common

function Get-WSLFileContent {
    [OutputType([string])]
    param(
        [string]
        $DistributionName,

        [string]
        $DistributionUser = "root",

        [string]
        $Path
    )

    $linuxCommand = "cat $Path 2>/dev/null || true"
    $invokeLinuxCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = $DistributionUser
        LinuxCommand = $linuxCommand
    }

    return Invoke-LinuxCommand @invokeLinuxCommandArguments
}

function Set-WSLFileContent {
    [OutputType([string])]
    param(
        [string]
        $DistributionName,

        [string]
        $DistributionUser = "root",

        [string]
        $Path,

        [string]
        $Content
    )

    $linuxCommand = "cat > $Path"
    $invokeLinuxCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = $DistributionUser
        LinuxCommand = $linuxCommand
    }

    return $Content | Invoke-LinuxCommand @invokeLinuxCommandArguments
}

function Invoke-WSLCommand {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [string]
        $Input,

        [string[]]
        $Arguments
    )

    if ($Input) {
        return $Input | wsl @Arguments | Out-String | Get-FormattedText | Test-CommandOutput
    }

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
        [Parameter(ValueFromPipeline=$true)]
        [string]
        $Input,

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

    if ($Input) {
        return $Input | Invoke-WSLCommand -Arguments $wslArguments
    }

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
        'Get-WSLFileContent',
        'Set-WSLFileContent'
        'Invoke-WSLCommand',
        'Invoke-WSLCommandInBackground',
        'Invoke-LinuxCommand',
        'Invoke-LinuxCommandInBackground',
        'Test-CommandOutput'
    )
}
Export-ModuleMember @export_members