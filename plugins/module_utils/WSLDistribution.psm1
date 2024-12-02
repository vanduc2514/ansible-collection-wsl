function Test-WSLDistributionExists {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    $wslDistros = wsl.exe --list --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $distributions = $wslDistros -split "`n" | Where-Object { $_.Trim() -eq $Name }
    return $distributions.Count -gt 0
}

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
            Name    = $parts[0]
            State   = $parts[1]
            Version = $parts[2]
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

$export_members = @{
    Function = "Test-WSLDistributionExists", "List-WSLDistribution", "Get-WSLDistribution"
}
Export-ModuleMember @export_members