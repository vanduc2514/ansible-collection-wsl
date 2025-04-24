#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Common
#AnsibleRequires -PowerShell ..module_utils.WSL

$spec = @{
    options = @{
        distribution = @{
            type = "str"
            required = $true
        }
        name = @{
            type = "str"
            required = $true
        }
        runlevel = @{
            type = "str"
            choices = @("0", "1", "2", "3", "4", "5", "6")
            default = "3"
        }
        enabled = @{
            type = "bool"
            default = $false
        }
        state = @{
            type = "str"
            choices = @("started", "stopped")
            default = "started"
        }
    }
    supports_check_mode = $true
}

function Get-ServiceStatus {
    param(
        [string]
        $DistributionName,

        [string]
        $ServiceName
    )

    try {
        $isServiceActiveCommandParams = @{
            DistributionName = $DistributionName
            DistributionUser = 'root'
            LinuxCommand = "service $ServiceName status 2>/dev/null || true"
        }
        $status = Invoke-LinuxCommand @isServiceActiveCommandParams
        $active = $status -match 'running|is up'

        $isServiceEnabledCommandParams = @{
            DistributionName = $DistributionName
            DistributionUser = 'root'
            LinuxCommand = "ls /etc/rc3.d/S*$ServiceName 2>/dev/null || true"
        }
        $enabled = [bool](Invoke-LinuxCommand @isServiceEnabledCommandParams)

        return @{
            active = $active
            enabled = $enabled
        }
    }
    catch {
        throw "Failed to get service status for '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
    }
}

function Get-ServiceRunLevel {
    param(
        [string]
        $DistributionName,

        [string]
        $ServiceName
    )

    try {
        $getRunLevelParams = @{
            DistributionName = $DistributionName
            DistributionUser = 'root'
            LinuxCommand = "find /etc/rc*.d -name '[SK]*$ServiceName' 2>/dev/null || true"
        }
        $runLevelLinks = Invoke-LinuxCommand @getRunLevelParams

        # Extract the runlevel from the link paths (e.g., /etc/rc3.d/S01service -> runlevel 3)
        $currentRunLevel = "3" # Default to 3 if no runlevel is found
        if ($runLevelLinks -match '/etc/rc([0-6]).d/S') {
            $currentRunLevel = $Matches[1]
        }

        return $currentRunLevel
    }
    catch {
        throw "Failed to get runlevel for service '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
    }
}

function Set-ServiceRunLevel {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $ServiceName,

        [string]
        $RunLevel
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Set service runlevel: $ServiceName to $RunLevel")) {
        try {
            $updateRcParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "update-rc.d $ServiceName defaults $RunLevel"
            }
            Invoke-LinuxCommand @updateRcParams | Out-Null
        }
        catch {
            throw "Failed to set runlevel for service '$ServiceName' to '$RunLevel' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

function Set-ServiceEnabled {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $ServiceName,

        [bool]
        $Enabled
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Set service enabled: $ServiceName to $Enabled")) {
        try {
            $action = if ($Enabled) { "defaults" } else { "remove" }
            $enableServiceParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "update-rc.d $ServiceName $action"
            }
            Invoke-LinuxCommand @enableServiceParams | Out-Null
        }
        catch {
            throw "Failed to $action service '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

function Set-ServiceActive {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $ServiceName,

        [bool]
        $Active
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Set service active: $ServiceName to $Active")) {
        try {
            $action = if ($Active) { "start" } else { "stop" }
            $serviceControlParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "service $ServiceName $action"
            }
            Invoke-LinuxCommand @serviceControlParams | Out-Null
        }
        catch {
            throw "Failed to $action service '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution_name = $module.Params.distribution
$service_name = $module.Params.name
$runlevel = $module.Params.runlevel
$enabled = $module.Params.enabled
$state = $module.Params.state
$check_mode = $module.CheckMode

try {
    $service_info = Get-ServiceStatus -DistributionName $distribution_name -ServiceName $service_name
    $current_runlevel = Get-ServiceRunLevel -DistributionName $distribution_name -ServiceName $service_name

    $module.Diff.before = @{
        active = $service_info.active
        enabled = $service_info.enabled
        runlevel = $current_runlevel
    }

    if ($runlevel -ne $current_runlevel) {
        $setRunLevelParams = @{
            DistributionName = $distribution_name
            ServiceName = $service_name
            RunLevel = $runlevel
            WhatIf = $check_mode
        }
        Set-ServiceRunLevel @setRunLevelParams
        Set-ModuleChanged -Module $module
    }

    if ($enabled -ne $service_info.enabled) {
        $enableParams = @{
            DistributionName = $distribution_name
            ServiceName = $service_name
            Enabled = $enabled
            WhatIf = $check_mode
        }
        Set-ServiceEnabled @enableParams
        Set-ModuleChanged -Module $module
    }

    if ($state -eq 'started' -and -not $service_info.active) {
        $startServiceParams = @{
            DistributionName = $distribution_name
            ServiceName = $service_name
            Active = $true
            WhatIf = $check_mode
        }
        Set-ServiceActive @startServiceParams
        Set-ModuleChanged -Module $module
    }

    if ($state -eq 'stopped' -and $service_info.active) {
        $stopServiceParams = @{
            DistributionName = $distribution_name
            ServiceName = $service_name
            Active = $false
            WhatIf = $check_mode
        }
        Set-ServiceActive @stopServiceParams
        Set-ModuleChanged -Module $module
    }

    $updated_service_info = Get-ServiceStatus -DistributionName $distribution_name -ServiceName $service_name
    $updated_runlevel = Get-ServiceRunLevel -DistributionName $distribution_name -ServiceName $service_name

    $module.Diff.after = @{
        active = $updated_service_info.active
        enabled = $updated_service_info.enabled
        runlevel = $updated_runlevel
    }
}
catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()