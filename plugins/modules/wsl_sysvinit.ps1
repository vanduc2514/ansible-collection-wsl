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

        return @{
            active = $active
        }
    }
    catch {
        throw "Failed to get service status for '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
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
$state = $module.Params.state
$check_mode = $module.CheckMode

try {
    $service_info = Get-ServiceStatus -DistributionName $distribution_name -ServiceName $service_name

    $module.Diff.before = @{
        active = $service_info.active
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

    $module.Diff.after = @{
        active = $updated_service_info.active
    }
}
catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
