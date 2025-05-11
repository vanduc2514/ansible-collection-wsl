#AnsibleRequires -PowerShell Common

function Test-WSLFileExist {
    [OutputType([bool])]
    param(
        [string]
        $DistributionName,

        [string]
        $Path
    )

    # The -e flag checks if the path exists regardless of type
    # But for symlinks (especially broken ones), we need to check specifically with -L
    $invokeLinuxCommandArguments = @{
        DistributionName = $DistributionName
        DistributionUser = 'root'
        LinuxCommand = "test -e '$Path' -o -L '$Path' && echo 'true' || echo 'false'"
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

function Create-LinuxProcess {
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
    return Create-WSLProcess -Argument $wslArgument
}

function Invoke-WSLCommand {
    param(
        [string[]]
        $Arguments
    )

    return $(wsl $Arguments) -join "`n" | Normalize-WSLOutput | Test-CommandOutput
}

function Create-WSLProcess {
    param(
        [string]
        $Argument
    )

    $processParams = @{
        CommandLine = "wsl.exe $Argument"
    }

    $result = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = "wsl.exe $Argument"
    }
    if ($result.ReturnValue -ne 0) {
        throw "Failed to invoke WSL command in win32 process. Return value: $($result.ReturnValue)"
    }

    return $result
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
        'Invoke-LinuxCommand',
        'Create-LinuxProcess',
        'Invoke-WSLCommand',
        'Create-WSLProcess'
    )
}
Export-ModuleMember @export_members
