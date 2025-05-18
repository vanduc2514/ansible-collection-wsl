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
        enabled = @{
            type = "bool"
            default = $false
        }
        daemon_reload = @{
            type = "bool"
            default = $false
        }
        dbus_timeout = @{
            type = "int"
            default = 120
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
            LinuxCommand = "systemctl is-active $ServiceName"
        }
        $active = (Invoke-LinuxCommand @isServiceActiveCommandParams).Trim() -eq 'active'

        $isServiceEnabledCommandParams = @{
            DistributionName = $DistributionName
            DistributionUser = 'root'
            LinuxCommand = "systemctl is-enabled $ServiceName 2>&1 || true"
        }
        $enabled = (Invoke-LinuxCommand @isServiceEnabledCommandParams).Trim() -eq 'enabled'

        return @{
            active = $active
            enabled = $enabled
        }
    } catch {
        throw "Failed to get service status for '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
    }
}


function Test-DBusConnection {
    param(
        [string]
        $DistributionName,

        [int]
        $TimeoutSeconds
    )

    try {
        $startTime = Get-Date
        $timeout = New-TimeSpan -Seconds $TimeoutSeconds
        $connected = $false

        while (-not $connected -and ((Get-Date) - $startTime) -lt $timeout) {
            $checkDbusParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                # Using busctl to check if we can connect to dbus
                LinuxCommand = "busctl --system --no-pager > /dev/null 2>&1 && echo 'connected' || echo 'disconnected'"
            }

            $result = (Invoke-LinuxCommand @checkDbusParams).Trim()

            if ($result -eq 'connected') {
                $connected = $true
            }
            else {
                Start-Sleep -Seconds 1
            }
        }

        return $connected
    }
    catch {
        throw "Failed to check DBus connection in WSL distribution '$DistributionName': $($_.Exception.Message)"
    }
}


function Invoke-DaemonReload {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Reload systemd daemon")) {
        try {
            $reloadParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "systemctl daemon-reload"
            }

            Invoke-LinuxCommand @reloadParams | Out-Null
        }
        catch {
            throw "Failed to reload systemd daemon in WSL distribution '$DistributionName': $($_.Exception.Message)"
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
            $action = if ($Enabled) { "enable" } else { "disable" }
            $enableServiceParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "systemctl $action $ServiceName 2>&1 || true"
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
            $enableServiceParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "systemctl $action $ServiceName"
            }

            Invoke-LinuxCommand @enableServiceParams | Out-Null
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
$enabled = $module.Params.enabled
$daemon_reload = $module.Params.daemon_reload
$dbus_timeout = $module.Params.dbus_timeout
$state = $module.Params.state
$check_mode = $module.CheckMode

try {
    # Wait for DBus to be connected before performing any operations
    $dbusConnected = Test-DBusConnection -DistributionName $distribution_name -TimeoutSeconds $dbus_timeout
    if (-not $dbusConnected) {
        throw "Timed out waiting for DBus to be ready in WSL distribution '$distribution_name' after $dbus_timeout seconds"
    }

    $service_info = Get-ServiceStatus -DistributionName $distribution_name -ServiceName $service_name
    $module.Diff.before = $service_info

    if ($daemon_reload) {
        $reloadParams = @{
            DistributionName = $distribution_name
            WhatIf = $check_mode
        }
        Invoke-DaemonReload @reloadParams
        $module.Result.daemon_reloaded = $true
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

    $module.Diff.after = Get-ServiceStatus -DistributionName $distribution_name -ServiceName $service_name

}
catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
