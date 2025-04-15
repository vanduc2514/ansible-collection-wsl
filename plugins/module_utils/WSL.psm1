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

function Invoke-WSLCommand {
    param(
        [string[]]
        $Arguments
    )

    return $(wsl @Arguments) -join "`n" | Normalize-WSLOutput | Test-CommandOutput
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
        'Invoke-WSLCommand',
        'Invoke-WSLCommandInBackground',
        'Invoke-LinuxCommand',
        'Invoke-LinuxCommandInBackground'
    )
}
Export-ModuleMember @export_members
