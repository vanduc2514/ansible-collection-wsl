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
        dbus_timeout = @{
            type = "int"
            default = 120
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
        $linuxCommandParams = @{
            DistributionName = $DistributionName
            DistributionUser = 'root'
            LinuxCommand = "systemctl is-active $ServiceName 2>/dev/null || echo 'inactive'"
        }
        $status = (Invoke-LinuxCommand @linuxCommandParams).Trim()

        return @{
            name = $ServiceName
            state = switch ($status) {
                'active' { 'started' }
                default { 'stopped' }
            }
            status = $status
        }
    }
    catch {
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

function Start-Service {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $ServiceName
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Start service: $ServiceName")) {
        try {
            $startServiceParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "systemctl start $ServiceName"
            }

            Invoke-LinuxCommand @startServiceParams | Out-Null
        }
        catch {
            throw "Failed to start service '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

function Stop-Service {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $ServiceName
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Stop service: $ServiceName")) {
        try {
            $stopServiceParams = @{
                DistributionName = $DistributionName
                DistributionUser = 'root'
                LinuxCommand = "systemctl stop $ServiceName"
            }

            Invoke-LinuxCommand @stopServiceParams | Out-Null
        }
        catch {
            throw "Failed to stop service '$ServiceName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution_name = $module.Params.distribution
$service_name = $module.Params.name
$desired_state = $module.Params.state
$dbus_timeout = $module.Params.dbus_timeout
$check_mode = $module.CheckMode

try {
    # Wait for DBus to be connected before performing any operations
    $dbusConnected = Test-DBusConnection -DistributionName $distribution_name -TimeoutSeconds $dbus_timeout
    if (-not $dbusConnected) {
        throw "Timed out waiting for DBus to be ready in WSL distribution '$distribution_name' after $dbus_timeout seconds"
    }

    # Get current service status
    $service_info = Get-ServiceStatus -DistributionName $distribution_name -ServiceName $service_name
    $module.Diff.before = $service_info

    # Check if action is needed
    $needs_change = $service_info.state -ne $desired_state

    if ($needs_change) {
        if ($desired_state -eq 'started') {
            $startServiceParams = @{
                DistributionName = $distribution_name
                ServiceName = $service_name
                WhatIf = $check_mode
            }
            Start-Service @startServiceParams
        }
        else {
            $stopServiceParams = @{
                DistributionName = $distribution_name
                ServiceName = $service_name
                WhatIf = $check_mode
            }
            Stop-Service @stopServiceParams
        }
        Set-ModuleChanged -Module $module
    }

    if (-not $check_mode) {
        $service_info = Get-ServiceStatus -DistributionName $distribution_name -ServiceName $service_name
    }
    else {
        $service_info.state = $desired_state
    }
    $module.Diff.after = $service_info

}
catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
