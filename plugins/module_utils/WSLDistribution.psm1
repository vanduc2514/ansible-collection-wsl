function List-WSLDistribution {
    $wslDistros = wsl.exe --list --verbose
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    # Split the output into lines and remove empty lines
    # Skip the header line and process the remaining lines
    $lines = $wslDistros -split "\n" | Where-Object { $_ -ne '' } | Select-Object -Skip 1

    # Create an array to store the distribution objects
    $distributions = @()

    foreach ($line in $lines) {
        # Split on multiple spaces and remove empty elements and asterisk
        $parts = $line -split '\s+' | Where-Object { $_ -ne '' -and $_ -ne '*' }

        # Create a new object with the specified properties
        $distro = [PSCustomObject]@{
            Name    = $parts[0] -replace '\u0000', ''
            State   = $parts[1] -replace '\u0000', ''
            Version = $parts[2] -replace '\u0000', ''
        }

        # Add the object to the array
        $distributions += $distro
    }

    return $distributions
}

function Get-WSLDistribution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    # Get all available distributions
    $distributions = List-WSLDistribution

    if (-not $distributions) {
        return $null
    }

    foreach ($distro in $distributions) {
        # If the distro found in distributions
        if ($distro.Name -eq $Name) {
            return $distro
        }
    }

    return $null
}

function Stop-WSLDistribution {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    try {
        wsl --terminate $Name
        return $true
    } catch {
        return $false
    }
}

function Write-IniConfig {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Config
    )

    foreach ($section in $$Config.Keys) {
        $section += "[$section]"
        $fields = $$Config[$section]

        foreach ($key in $fields.Keys) {
            $value = $fields[$key]
            if ($value -is [bool]) {
                $value = $value.ToString().ToLower()
            }
            $section += "$key = $value"
        }

        $section += ""
    }

    return $section -join "`n"
}

function Read-IniConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ConfigContent
    )

    $config = @{}
    $current_section = $null

    $$ConfigContent -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^\[(.+)\]$') {
            $current_section = $matches[1]
            $config[$current_section] = @{}
        }
        elseif ($line -match '^([^=]+?)\s*=\s*(.+)$' -and $current_section) {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Convert string boolean values to actual boolean
            if ($value -match '^(true|false)$') {
                $value = [System.Convert]::ToBoolean($value)
            }

            $config[$current_section][$key] = $value
        }
    }

    return $config
}

function Test-Config-Change {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $CurrentConfig,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $DesiredConfig
    )

    foreach ($section in $DesiredConfig.Keys) {
        # Check if section exists in current config
        if (-not $CurrentConfig.ContainsKey($section)) {
            return $true
        }

        # Check each key in the section
        foreach ($key in $DesiredConfig[$section].Keys) {
            if (-not $CurrentConfig[$section].ContainsKey($key) -or
                $CurrentConfig[$section][$key] -ne $DesiredConfig[$section][$key]) {
                return $true
            }
        }
    }

    return $false
}


function Set-DistributionDiffInfo {
    param (
        [Parameter(Mandatory)]
        [Object]
        $Distribution,

        [Parameter(Mandatory)]
        [Hashtable]
        $DiffTarget
    )

    if ($Distribution) {
        $DiffTarget.wsl_distribution = @{
            name = $Distribution.Name
            arch_version = $Distribution.Version
            state = $Distribution.State
        }
    }
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

$export_members = @{
    Function = @(
        'List-WSLDistribution',
        'Get-WSLDistribution',
        'Stop-WSLDistribution',
        'Set-DistributionDiffInfo',
        'Get-HashFromURL',
        'Write-IniConfig',
        'Read-IniConfig',
        'Test-Config-Change'
    )
}
Export-ModuleMember @export_members