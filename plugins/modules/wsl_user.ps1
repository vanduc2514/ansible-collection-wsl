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
        login_shell = @{
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
        authorized_key_append = @{
            type     = "bool"
            default  = $false
        }
        authorized_keys_path = @{
            type     = "path"
        }
        remove_authorized_keys = @{
            type     = "bool"
            default  = $false
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
        , @("authorized_key", "remove_authorized_keys")
    )
}

function Test-RootUser {
    param(
        [string]
        $UserName
    )

    return $UserName -eq 'root'
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

    $UID = if ($result -match "uid=(\d+)") {
        [int]$Matches[1]
    } else {
        $null
    }

    # Get home directory
    $homeCmd = "getent passwd $UserName 2>/dev/null | cut -d: -f6 || echo ''"
    $homePath = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $homeCmd).Trim()

    # Get shell
    $shellCmd = "getent passwd $UserName 2>/dev/null | cut -d: -f7 || echo ''"
    $loginShell = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $shellCmd).Trim()

    # Check sudo status
    $sudoCmd = "{ grep -q '^$UserName\\s\\+ALL\\s*=' /etc/sudoers 2>/dev/null || [ -f /etc/sudoers.d/$UserName ]; } && echo 'true' || echo 'false'"
    $isSudo = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd).Trim() -eq "true"

    return @{
        name = $UserName
        uid = $UID
        home_path = $homePath
        login_shell = $loginShell
        sudo = $isSudo
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
    $userdel = "userdel $args $UserName 2>/dev/null"

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


function New-UserHomeDirectory {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $UserName,

        [string]
        $Path
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create home directory: $Path")) {
        try {
            $newWSLDirectoryCommandArguments = @{
                DistributionName = $DistributionName
                Owner = "${UserName}"
                Mode = 700
                Path = $Path
            }
            New-WSLDirectory @newWSLDirectoryCommandArguments | Out-Null
        } catch {
            throw "Failed to create home directory '$Path' for user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
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
        $HomePath,

        [string]
        $LoginShell
    )

    $userAddCmdArgs = @(
        if ($UID) { '--uid', $UID }
        if ($LoginShell) { '--shell', $LoginShell }
    )

    $userAddCmd = "useradd --home-dir $HomePath $($userAddCmdArgs -join ' ')"

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create user: $UserName")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand "$userAddCmd $UserName" | Out-Null
        } catch {
            throw "Failed to create user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Set-User {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $UserName,

        [string]
        $UID,

        [string]
        $HomePath,

        [string]
        $LoginShell
    )

    $userModCmdArgs = @(
        if ($UID) { '--uid', $UID }
        if ($HomePath) { '--home', $HomePath }
        if ($LoginShell) { '--shell', $LoginShell }
    )

    $userModCmd = "usermod $($userModCmdArgs -join ' ')"

    if ($userModCmdArgs.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($DistributionName, "Modify user properties for: $UserName")) {
            try {
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand "$userModCmd $UserName" | Out-Null
            } catch {
                throw "Failed to modify properties for user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
            }
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


function Set-Password {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $UserName,

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


function New-AuthorizedKeysFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $UserName,

        [string]
        $Path
    )

    $parent = Get-ParentDirectory -Path $Path

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create authorized_keys file: $Path")) {
        try {
            $newWSLDirectoryCommandArguments = @{
                DistributionName = $DistributionName
                Owner = $UserName
                Mode = 700
                Path = $parent
            }
            New-WSLDirectory @newWSLDirectoryCommandArguments | Out-Null

            $newWSLFileCommandArguments = @{
                DistributionName = $DistributionName
                Owner = $UserName
                Mode = 600
                Path = $Path
            }
            New-WSLFile @newWSLFileCommandArguments | Out-Null
        } catch {
            throw "Failed to create authorized_keys file '$Path' for user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}


function Test-AuthorizedKeyExist {
    param(
        [string]
        $DistributionName,

        [string]
        $AuthorizedKey,

        [string]
        $AuthorizedKeysPath
    )

    try {
        $checkCmd = "grep --quiet '^$AuthorizedKey\$' '$AuthorizedKeysPath' 2>/dev/null && echo 'true' || echo 'false'"
        $result = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $checkCmd
        return $result.Trim() -eq 'true'
    } catch {
        return $false
    }
}


function Set-AuthorizedKey {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $AuthorizedKey,

        [bool]
        $Append,

        [string]
        $AuthorizedKeysPath
    )

    if ($PSCmdlet.ShouldProcess($DistributionName, "Add authorized key to: $AuthorizedKeysPath")) {
        try {
            $setWSLFileContent = @{
                DistributionName = $DistributionName
                Append = $Append
                Content = "$AuthorizedKey`n"
                Path = $AuthorizedKeysPath
            }
            Set-WSLFileContent @setWSLFileContent | Out-Null
        } catch {
            throw "Failed to set authorized key in '$AuthorizedKeysPath' for user '$UserName' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$distribution_name = $module.Params.distribution
$uid = $module.Params.uid
$home_path = $module.Params.home_path
$login_shell = $module.Params.login_shell
$sudo = $module.Params.sudo
$raw_password = $module.Params.password
$authorized_key = $module.Params.authorized_key
$authorized_key_append = $module.Params.authorized_key_append
$authorized_keys_path = $module.Params.authorized_keys_path
$remove_home = $module.Params.remove_home
$state = $module.Params.state
$check_mode = $module.CheckMode

$home_path = if ($home_path) {
    $home_path
} elseif (Test-RootUser -UserName $name) {
    '/root'
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
    $user = Get-UserInfo -DistributionName $distribution_name -UserName $name
    $module.Diff.before = $user

    # Handle user removal
    if ($state -eq "absent") {
        if ($user) {
            $removeUserParams = @{
                DistributionName = $distribution_name
                UserName = $name
                RemoveHome = $remove_home
                WhatIf = $check_mode
            }

            Remove-User @removeUserParams
            Set-ModuleChanged -Module $module
            $module.Diff.after = $null
        }
        $module.ExitJson()
    }

    if (-not $user) {
        $newUserParams = @{
            DistributionName = $distribution_name
            UserName = $name
            UID = $uid
            HomePath = $home_path
            LoginShell = $login_shell
            WhatIf = $check_mode
        }
        New-User @newUserParams
        $user = Get-UserInfo -DistributionName $distribution_name -UserName $name
        Set-ModuleChanged -Module $module
    }

    if (-not $(Test-WSLFileExist -DistributionName $distribution_name -Path $home_path)) {
        $newUserHomeDirectoryParams = @{
            DistributionName = $distribution_name
            UserName = $name
            Path = $home_path
            WhatIf = $check_mode
        }
        New-UserHomeDirectory @newUserHomeDirectoryParams
        Set-ModuleChanged -Module $module
    }

    if (-not $(Test-WSLFileExist -DistributionName $distribution_name -Path $authorized_keys_path)) {
        $newAuthorizedKeysFile = @{
            DistributionName = $distribution_name
            UserName = $name
            Path = $authorized_keys_path
            WhatIf = $check_mode
        }
        New-AuthorizedKeysFile @newAuthorizedKeysFile
        Set-ModuleChanged -Module $module
    }

    if ($uid -and $(Test-RootUser -UserName $name)) {
        $module.Warn('Cannot change uid of root user')
    } elseif ($uid -and $user.uid -ne $uid) {
        $setUserUIDCommandArguments = @{
            DistributionName = $distribution_name
            UserName = $name
            UID = $uid
            WhatIf = $check_mode
        }
        Set-User @setUserUIDCommandArguments
        Set-ModuleChanged -Module $module
    }

    if ($home_path -and $user.home_path -ne $home_path) {
        $setUserHomePathCommandArguments = @{
            DistributionName = $distribution_name
            UserName = $name
            HomePath = $home_path
            WhatIf = $check_mode
        }
        Set-User @setUserHomePathCommandArguments
        Set-ModuleChanged -Module $module
    }

    if ($login_shell -and $user.login_shell -ne $login_shell) {
        $setUserLoginShellCommandArguments = @{
            DistributionName = $distribution_name
            UserName = $name
            LoginShell = $login_shell
            WhatIf = $check_mode
        }
        Set-User @setUserLoginShellCommandArguments
        Set-ModuleChanged -Module $module
    }

    if (-not $sudo -and $(Test-RootUser -UserName $name)) {
        $module.Warn('Cannot change sudo access of root user')
    } elseif ($sudo -ne $user.sudo) {
        $setSudoAccessParams = @{
            DistributionName = $distribution_name
            UserName = $name
            Sudo = $sudo
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

    if ($authorized_key) {
        $testAuthorizedKeyExist = @{
            DistributionName = $distribution_name
            AuthorizedKey = $authorized_key
            AuthorizedKeysPath = $authorized_keys_path
        }
        $authorizedKeyExist = Test-AuthorizedKeyExist @testAuthorizedKeyExist

        if (-not $authorizedKeyExist) {
            $setAuthorizedKeyParams = @{
                DistributionName = $distribution_name
                AuthorizedKey = $authorized_key
                Append = $authorized_key_append
                AuthorizedKeysPath = $authorized_keys_path
                WhatIf = $check_mode
            }
            Set-AuthorizedKey @setAuthorizedKeyParams
            Set-ModuleChanged -Module $module
        }
    }

    $module.Diff.after = Get-UserInfo -DistributionName $distribution_name -UserName $name
    $module.Result.user = $module.Diff.after

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
