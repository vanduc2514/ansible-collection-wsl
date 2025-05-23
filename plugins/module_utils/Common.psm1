function New-Win32Process {
    param(
        [string]
        $CommandLine
    )

    # Hack for running interactive command in non-interactive shell
    return Invoke-CimMethod Win32_Process -MethodName create -Arguments @{
        CommandLine = $CommandLine
    }
}

function Remove-Win32Process {
    param(
        [string]
        $ProcessId,

        [string]
        $ProcessName
    )

    # Build the WQL query based on provided parameters
    $query = "SELECT * FROM Win32_Process"
    if ($ProcessId -and $ProcessName) {
        $query += " WHERE ProcessId = '$ProcessId' AND Name = '$ProcessName'"
    }
    elseif ($ProcessId) {
        $query += " WHERE ProcessId = '$ProcessId'"
    }
    elseif ($ProcessName) {
        $query += " WHERE Name = '$ProcessName'"
    }

    # Get the process(es) using WMI query
    $processes = Get-WmiObject -Query $query

    # Terminate the process(es)
    foreach ($process in $processes) {
        $process.Terminate()
    }

    Remove-CimInstance -Query $query
}

function Get-HashFromURL {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    $stringToHash = $Url.ToLowerInvariant()  # Normalize URL

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToHash))
        return [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
    }
    finally {
        $sha.Dispose()
    }
}

function Normalize-WSLOutput {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [Object[]]
        $Output
    )

    return $Output -join "`n" -replace '\u0000', ''
}

function Get-ParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if ([string]::IsNullOrEmpty($Path)) {
        return $null
    }

    $normalizedPath = $Path.Replace('\', '/')

    if ($normalizedPath.EndsWith('/')) {
        $normalizedPath = $normalizedPath.TrimEnd('/')
    }

    $lastSlashIndex = $normalizedPath.LastIndexOf('/')

    if ($lastSlashIndex -eq -1) {
        return ""
    }

    if ($lastSlashIndex -eq 0) {
        return "/"
    }

    return $normalizedPath.Substring(0, $lastSlashIndex)
}

function Set-ModuleChanged {
    param(
        [Ansible.Basic.AnsibleModule]
        $Module
    )

    if (-not $Module.CheckMode) {
        $Module.Result.changed = $true
    }
}

$export_members = @{
    Function = @(
        'New-Win32Process',
        'Remove-Win32Process',
        'Get-HashFromURL',
        'Normalize-WSLOutput',
        'Get-ParentDirectory',
        'Set-ModuleChanged'
    )
}
Export-ModuleMember @export_members
