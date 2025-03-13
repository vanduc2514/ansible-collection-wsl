#AnsibleRequires -PowerShell Common

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

$export_members = @{
    Function = @(
        'Test-CommandOutput',
        'Invoke-WSLCommand',
        'Invoke-WSLCommandInBackground',
        'Invoke-LinuxCommand',
        'Invoke-LinuxCommandInBackground'
    )
}
Export-ModuleMember @export_members