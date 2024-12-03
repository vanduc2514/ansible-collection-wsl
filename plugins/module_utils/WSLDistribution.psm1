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

$export_members = @{
    Function = "List-WSLDistribution", "Get-WSLDistribution", "Stop-WSLDistribution", "Set-DistributionDiffInfo"
}
Export-ModuleMember @export_members