#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Common
#AnsibleRequires -PowerShell ..module_utils.WSL

$spec = @{
    options = @{
        distribution = @{
            type     = "str"
            required = $true
        }
        name = @{
            type     = "str"
            required = $true
        }
        uid = @{
            type     = "int"
        }
        home_path = @{
            type     = "str"
        }
        shell = @{
            type     = "str"
        }
        sudo = @{
            type     = "bool"
            default  = $false
        }
        password = @{
            type     = "str"
            no_log   = $true
        }
        authorized_key = @{
            type     = "str"
            no_log   = $true
        }
        authorized_keys_path = @{
            type     = "path"
        }
        remove_home = @{
            type     = "bool"
            default  = $false
        }
        state = @{
            type     = "str"
            choices  = @("present", "absent")
            default  = "present"
        }
    }
    supports_check_mode = $true
    mutually_exclusive = @(
        ,@("authorized_key", "authorized_keys_path")
    )
}

function Get-UserInfo {
    param(
        [string]
        $DistributionName,

        [string]
        $UserName
    )

    $linuxCommand = "id $UserName 2>/dev/null || echo 'USER_NOT_FOUND'"
    $result = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $linuxCommand

    if ($result -match "USER_NOT_FOUND") {
        return $null
    }

    # Parse the id command output
    $uidMatch = $result -match "uid=(\d+)"

    # Get home directory
    $homeCmd = "getent passwd $UserName 2>/dev/null | cut -d: -f6 || echo ''"
    $homePath = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $homeCmd).Trim()

    # Get shell
    $shellCmd = "getent passwd $UserName 2>/dev/null | cut -d: -f7 || echo ''"
    $login_shell = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $shellCmd).Trim()

    # Check sudo status
    $sudoCmd = "grep -q '^$UserName\\s\\+ALL\\s*=' /etc/sudoers 2>/dev/null || [ -f /etc/sudoers.d/$UserName ] && echo 'true' || echo 'false'"
    $sudo = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd).Trim() -eq "true"

    return @{
        username = $UserName
        uid = $uid
        home = $homePath
        login_shell = $login_shell
        sudo = $sudo
        exists = $true
    }
}

function New-User {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $UserName,

        [int]
        $UID,

        [string]
        $UserHome,

        [string]
        $LoginShell
    )

    $userCmd = "useradd --home-dir '$UserHome'"

    if ($Shell) {
        $userCmd += " --shell '$Shell'"
    }

    if ($Uid) {
        $userCmd += " --uid $Uid"
    }

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create user: $UserName")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand "$userCmd $UserName" | Out-Null
        } catch {
            throw "Failed to create user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

function Set-Password {
    param(
        [string]
        $DistributionName,

        [string]
        $UserName

        [string]
        $RawPassword
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Set password for user: $UserName")) {
        $passwordCmd = "echo '${UserName}:${RawPassword}' | chpasswd"
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $passwordCmd | Out-Null
        } catch {
            throw "Failed to set password for user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

function Set-SudoAccess {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $UserName,

        [bool]
        $Sudo
    )

    if ($Sudo) {
        $sudoCmd = "echo '$UserName ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$UserName && chmod 0440 /etc/sudoers.d/$UserName"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Grant sudo access to user: $UserName")) {
            try {
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd | Out-Null
            } catch {
                throw "Failed to grant sudo access to user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
            }
        }
    } else {
        $sudoCmd = "rm -f /etc/sudoers.d/$UserName"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Remove sudo access from user: $UserName")) {
            try {
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd | Out-Null
            } catch {
                throw "Failed to remove sudo access from user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
            }
        }
    }
}

function Remove-User {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $UserName,

        [bool]
        $RemoveHome = $false
    )

    $args = if ($RemoveHome) { "--remove" } else { "" }
    $userdel = "userdel $args $UserName"

    if ($PSCmdlet.ShouldProcess($DistributionName, "Remove user: $UserName")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $userdel | Out-Null
            # Clean up sudo file if it exists
            $sudoCleanup = "rm -f /etc/sudoers.d/$UserName"
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCleanup | Out-Null
        } catch {
            throw "Failed to remove user '$UserName' from WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution_name = $module.Params.distribution
$name = $module.Params.name
$uid = $module.Params.uid
$home_path = $module.Params.home_path
$login_shell = $module.Params.shell
$sudo = $module.Params.sudo
$raw_password = $module.Params.password
$authorized_key = $module.Params.authorized_key
$authorized_keys_path = $module.Params.authorized_keys_path
$remove_home = $module.Params.remove_home
$state = $module.Params.state
$check_mode = $module.CheckMode

$home_path = if ($home_path) {
    $home_path
} else {
    "/home/$name"
}

$authorized_keys_path = if ($authorized_keys_path) {
    $authorized_keys_path
} else {
    "$home_path/.ssh/authorized_keys"
}

try {
    # Get current user information
    $user = Get-UserInfo -DistributionName $distribution_name -Username $name
    $module.Diff.before = $user

    # Handle user removal
    if ($state -eq "absent") {
        if ($user) {
            $removeUserParams = @{
                DistributionName = $distribution_name
                UserName = $name
                RemoveHome = $remove_home
                WhatIf = check_mode
            }

            Remove-User @removeUserParams
            Set-ModuleChanged -Module $module
            $module.Diff.after = $null
        }
        $module.ExitJson()
    }

    if (-not $(Test-WSLFileExist -DistributionName $distribution_name -Path $home_path)) {
        $newUserHomeDirectoryParams = @{
            DistributionName = $distribution_name
            Path = $home_path
            WhatIf = $check_mode
        }
        New-UserHomeDirectory @newUserHomeDirectoryParams # TODO: Implement this function
        Set-ModuleChanged -Module $module
    }

    if (-not $(Test-WSLFileExist -DistributionName $distribution_name -Path $authorized_keys_path)) {
        $newAuthorizedKeysFile = @{
            DistributionName = $distribution_name
            Path = $authorized_keys_path
            WhatIf = $check_mode
        }
        New-AuthorizedKeysFile @newAuthorizedKeysFile # TODO: implement this function, should create parent first then new file
        Set-ModuleChanged -Module $module
    }

    if (-not $user) {
        $newUserParams = @{
            DistributionName = $distribution_name
            UserName = $name
            CreateHome = $create_home
            UserHome = $home_path
            Shell = $login_shell
            Password = $raw_password
            Uid = $uid
            WhatIf = $check_mode
        }
        New-User @newUserParams
        $user = Get-UserInfo -DistributionName $distribution_name -Username $name
        Set-ModuleChanged -Module $module
    }

    if ($user.user_name -ne $name) {
        $setUserNameParams = @{
            DistributionName = $distribution_name
            UserName = $name
            WhatIf = $check_mode
        }
        Set-UserName @setUserNameParams #TODO: Implement this function, create a common function which user usermod and pass argument to it
        Set-ModuleChanged -Module $module
    }

    if ($user.uid -ne $uid) {
        $setUserUIDParams = @{
            DistributionName = $distribution_name
            UserName = $name
            UserUID = $uid
            WhatIf = $check_mode
        }
        Set-UserUID @setUserUIDParams #TODO: Implement this function, create a common function which user usermod and pass argument to it
        Set-ModuleChanged -Module $module
    }

    if ($user.home_path -ne $home_path) {
        $setUserHomePathParams = @{
            DistributionName = $distribution_name
            UserName = $name
            UserHome = $home_path
            WhatIf = $check_mode
        }
        Set-UserHome @setUserHomePathParams #TODO: Implement this function, create a common function which user usermod and pass argument to it
        Set-ModuleChanged -Module $module
    }

    if ($user.login_shell -ne $login_shell) {
        $setUserHomePathParams = @{
            DistributionName = $distribution_name
            UserName = $name
            LoginShell = $login_shell
            WhatIf = $check_mode
        }
        Set-UserHome @setUserHomePathParams #TODO: Implement this function, create a common function which user usermod and pass argument to it
        Set-ModuleChanged -Module $module
    }

    if ($sudo -and $sudo -ne $user.sudo) {
        $setSudoAccessParams = {
            DistributionName = $name
            UserName = $name
            WhatIf = $check_mode
        }
        Set-SudoAccess @setSudoAccessParams
        Set-ModuleChanged -Module $module
    }


    if ($raw_password) {
        $setPasswordParams = @{
            DistributionName = $distribution_name
            UserName = $name
            RawPassword = $raw_password
            WhatIf = $check_mode
        }
        Set-Password @setPasswordParams
        Set-ModuleChanged -Module $module
    }

    $testHavingAuthorizedKeyParams = {
        DistributionName = $distribution_name
        AuthorizedKey = $authorized_key
        AuthorizedKeysPath = $authorized_keys_path
    }
    $hasAuthorizedKey = Test-HavingAuthorizedKey @testHavingAuthorizedKeyParams # TODO: check if authorized_key file in the path contain authorized_key value

    if ($authorized_key -and -not $hasAuthorizedKey) {
        setAuthorizedKeyParams = {
            DistributionName = $distribution_name
            AuthorizedKey = $authorized_key
            AuthorizedKeyPath = $authorized_keys_path
            WhatIf = $check_mode
        }
        Set-AuthorizedKey @setAuthorizedKeyParams # TODO: append value to the end of authorized_key
        Set-ModuleChanged -Module $module
    }

    if ($module.Result.changed) {
        $module.Diff.after = Get-UserInfo -DistributionName $distribution_name -Username $name
    }

    $module.Result.user = $module.Diff.after

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
