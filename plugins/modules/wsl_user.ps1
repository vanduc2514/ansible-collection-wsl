#!powershell
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Common
#AnsibleRequires -PowerShell ..module_utils.WSL

$spec = @{
    options = @{
        name = @{
            type     = "str"
            required = $true
        }
        distribution = @{
            type     = "str"
            required = $true
        }
        comment = @{
            type     = "str"
            default  = ""
        }
        create_home = @{
            type     = "bool"
            default  = $true
        }
        home = @{
            type     = "str"
        }
        shell = @{
            type     = "str"
        }
        password = @{
            type     = "str"
            no_log   = $true
        }
        authorized_key = @{
            type     = "str"
        }
        authorized_key_path = @{
            type     = "path"
        }
        generate_host_keys = @{
            type     = "bool"
            default  = $false
        }
        ssh_key_path = @{
            type     = "str"
        }
        uid = @{
            type     = "int"
        }
        sudo = @{
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
        ,@("authorized_key", "authorized_key_path")
    )
}

function Get-UserInfo {
    param(
        [string]
        $DistributionName,

        [string]
        $Username
    )

    $linuxCommand = "id $Username 2>/dev/null || echo 'USER_NOT_FOUND'"
    $result = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $linuxCommand

    if ($result -match "USER_NOT_FOUND") {
        return $null
    }

    # Parse the id command output
    $uidMatch = $result -match "uid=(\d+)"

    # Get home directory
    $homeCmd = "getent passwd $Username 2>/dev/null | cut -d: -f6 || echo ''"
    $homePath = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $homeCmd).Trim()

    # Get shell
    $shellCmd = "getent passwd $Username 2>/dev/null | cut -d: -f7 || echo ''"
    $shell = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $shellCmd).Trim()

    # Check sudo status
    $sudoCmd = "grep -q '^$Username\\s\\+ALL\\s*=' /etc/sudoers 2>/dev/null || [ -f /etc/sudoers.d/$Username ] && echo 'true' || echo 'false'"
    $sudo = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd).Trim() -eq "true"

    return @{
        name = $Username
        uid = $uid
        home = $homePath
        shell = $shell
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
        $Username,

        [bool]
        $CreateHome = $true,

        [string]
        $UserHome,

        [string]
        $Shell,

        [string]
        $Password,

        [int]
        $Uid
    )

    # Build useradd command
    $usercmd = "useradd"

    if (-not $CreateHome) {
        $usercmd += " --no-create-home"
    } elseif ($UserHome) {
        $usercmd += " --home-dir '$UserHome'"
        # Create the directory if it doesn't exist
        $mkdirCmd = "mkdir -p '$UserHome'"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Create home directory: $UserHome")) {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $mkdirCmd | Out-Null
        }
    }

    if ($Shell) {
        $usercmd += " --shell '$Shell'"
    }

    if ($Uid) {
        $usercmd += " --uid $Uid"
    }

    $usercmd += " $Username"

    if ($PSCmdlet.ShouldProcess($DistributionName, "Create user: $Username")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $usercmd | Out-Null

            # Set password if specified
            if ($Password) {
                $passwordCmd = "echo '${Username}:${Password}' | chpasswd"
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $passwordCmd | Out-Null
            }

            return $true
        } catch {
            throw "Failed to create user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }

    return $false
}

function Update-User {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Username,

        [string]
        $UserHome,

        [string]
        $Shell,

        [string]
        $Password,

        [int]
        $Uid,

        [hashtable]
        $user
    )

    # Build usermod command
    $usercmd = "usermod"
    $changes = $false

    if ($UserHome -and $UserHome -ne $user.home) {
        $usercmd += " --home '$UserHome' --move-home"
        $changes = $true

        # Create the directory if it doesn't exist
        $mkdirCmd = "mkdir -p '$UserHome'"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Create home directory: $UserHome")) {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $mkdirCmd | Out-Null
        }
    }

    if ($Shell -and $Shell -ne $user.shell) {
        $usercmd += " --shell '$Shell'"
        $changes = $true
    }

    if ($Uid -and $Uid -ne $user.uid) {
        $usercmd += " --uid $Uid"
        $changes = $true
    }

    if ($changes) {
        $usercmd += " $Username"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Update user: $Username")) {
            try {
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $usercmd | Out-Null
            } catch {
                throw "Failed to update user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
            }
        }
    }

    # Set password if specified
    if ($Password) {
        if ($PSCmdlet.ShouldProcess($DistributionName, "Set password for user: $Username")) {
            $passwordCmd = "echo '${Username}:${Password}' | chpasswd"
            try {
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $passwordCmd | Out-Null
                $changes = $true
            } catch {
                throw "Failed to set password for user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
            }
        }
    }

    return $changes
}

function Set-SudoAccess {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Username,

        [bool]
        $Sudo,

        [bool]
        $CurrentSudo
    )

    if ($Sudo -eq $CurrentSudo) {
        return $false
    }

    if ($Sudo) {
        $sudoCmd = "echo '$Username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$Username && chmod 0440 /etc/sudoers.d/$Username"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Grant sudo access to user: $Username")) {
            try {
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd | Out-Null
                return $true
            } catch {
                throw "Failed to grant sudo access to user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
            }
        }
    } else {
        $sudoCmd = "rm -f /etc/sudoers.d/$Username"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Remove sudo access from user: $Username")) {
            try {
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd | Out-Null
                return $true
            } catch {
                throw "Failed to remove sudo access from user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
            }
        }
    }

    return $false
}

function Set-AuthorizedKey {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Username,

        [string]
        $AuthorizedKey,

        [string]
        $HomeDir
    )

    if (-not $AuthorizedKey) {
        return $false
    }

    if (-not $HomeDir) {
        $homeCmd = "getent passwd $Username | cut -d: -f6"
        $HomeDir = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $homeCmd
        if (-not $HomeDir) {
            throw "Home directory not found for user '$Username' in WSL distribution '$DistributionName'"
        }
    }

    # Get current authorized keys
    $currentKeysCmd = "test -f '$HomeDir/.ssh/authorized_keys' && cat '$HomeDir/.ssh/authorized_keys' || echo ''"
    $currentKeys = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $currentKeysCmd

    # Compare to see if changes are needed
    $currentKeysNormalized = $currentKeys.Trim()
    $keyNormalized = $AuthorizedKey.Trim()

    if ($currentKeysNormalized -eq $keyNormalized) {
        return $false
    }

    # Ensure .ssh directory exists with proper permissions
    $sshDirCmd = "mkdir -p '$HomeDir/.ssh' && chmod 700 '$HomeDir/.ssh' && chown ${Username}:${Username} '$HomeDir/.ssh'"
    if ($PSCmdlet.ShouldProcess($DistributionName, "Create SSH directory for user: $Username")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sshDirCmd | Out-Null
        } catch {
            throw "Failed to create SSH directory for user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }

    # Write authorized keys
    $authorizedKeysCmd = "echo '$keyNormalized' > '$HomeDir/.ssh/authorized_keys' && chmod 600 '$HomeDir/.ssh/authorized_keys' && chown ${Username}:${Username} '$HomeDir/.ssh/authorized_keys'"
    if ($PSCmdlet.ShouldProcess($DistributionName, "Set SSH authorized keys for user: $Username")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $authorizedKeysCmd | Out-Null
            return $true
        } catch {
            throw "Failed to set SSH authorized keys for user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }

    return $false
}

function Generate-HostKeys {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Username,

        [string]
        $HomeDir,

        [string]
        $KeyPath
    )

    if (-not $HomeDir) {
        $homeCmd = "getent passwd $Username | cut -d: -f6"
        $HomeDir = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $homeCmd
        if (-not $HomeDir) {
            throw "Home directory not found for user '$Username' in WSL distribution '$DistributionName'"
        }
    }

    # Determine SSH key path
    $authorizedKeyPath = if ($KeyPath) { $KeyPath } else { "$HomeDir/.ssh/id_rsa" }

    # Check if key already exists
    $checkKeyCmd = "test -f '$authorizedKeyPath' && echo 'EXISTS' || echo 'NOT_EXISTS'"
    $keyExists = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $checkKeyCmd).Trim() -eq "EXISTS"

    if ($keyExists) {
        return @{
            changed = $false
            key_path = $authorizedKeyPath
            public_key_path = "$authorizedKeyPath.pub"
        }
    }

    # Ensure .ssh directory exists with proper permissions
    $sshDirCmd = "mkdir -p '$HomeDir/.ssh' && chmod 700 '$HomeDir/.ssh' && chown ${Username}:${Username} '$HomeDir/.ssh'"
    if ($PSCmdlet.ShouldProcess($DistributionName, "Create SSH directory for user: $Username")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sshDirCmd | Out-Null
        } catch {
            throw "Failed to create SSH directory for user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }

    # Generate SSH key
    $generateKeyCmd = "ssh-keygen -t rsa -b 4096 -f '$authorizedKeyPath' -N '' -C '$Username@wsl' && chmod 600 '$authorizedKeyPath' && chmod 644 '$authorizedKeyPath.pub' && chown -R ${Username}:${Username} '$HomeDir/.ssh'"
    if ($PSCmdlet.ShouldProcess($DistributionName, "Generate SSH key for user: $Username")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $generateKeyCmd | Out-Null

            # Add to authorized_keys if not already there
            $pubKeyCmd = "cat '$authorizedKeyPath.pub'"
            $pubKey = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $pubKeyCmd

            # Get current authorized keys
            $currentKeysCmd = "test -f '$HomeDir/.ssh/authorized_keys' && cat '$HomeDir/.ssh/authorized_keys' || echo ''"
            $currentKeys = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $currentKeysCmd

            # Add key to authorized_keys if not already there
            if ($currentKeys -notmatch [regex]::Escape($pubKey)) {
                $authorizedKeysCmd = "echo '$pubKey' >> '$HomeDir/.ssh/authorized_keys' && chmod 600 '$HomeDir/.ssh/authorized_keys' && chown ${Username}:${Username} '$HomeDir/.ssh/authorized_keys'"
                Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $authorizedKeysCmd | Out-Null
            }

            return @{
                changed = $true
                key_path = $authorizedKeyPath
                public_key_path = "$authorizedKeyPath.pub"
                public_key = $pubKey
            }
        } catch {
            throw "Failed to generate SSH key for user '$Username' in WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }

    return @{
        changed = $false
    }
}

function Remove-User {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Username,

        [bool]
        $RemoveHome = $false
    )

    $args = if ($RemoveHome) { "--remove" } else { "" }
    $userdel = "userdel $args $Username"

    if ($PSCmdlet.ShouldProcess($DistributionName, "Remove user: $Username")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $userdel | Out-Null

            # Clean up sudo file if it exists
            $sudoCleanup = "rm -f /etc/sudoers.d/$Username"
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCleanup | Out-Null

            return $true
        } catch {
            throw "Failed to remove user '$Username' from WSL distribution '$DistributionName': $($_.Exception.Message)"
        }
    }

    return $false
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution = $module.Params.distribution
$name = $module.Params.name # TODO: Throw error if the user is root and exit
$uid = $module.Params.uid
$sudo = $module.Params.sudo
$create_home = $module.Params.create_home # TODO: remove this option and always create home folder specified in home_path
$home_path = $module.Params.home_path
$remove_home = $module.Params.remove_home
$shell = $module.Params.shell
$password = $module.Params.password # TODO: if this option is specified, then always update password, this is non-idempotem
$authorized_key = $module.Params.authorized_key # TODO: If specified, append this value to authroized_keys file of the user
$authorized_key_path = $module.Params.authorized_key_path
$generate_host_keys = $module.Params.generate_host_keys # TODO: remove this option
$state = $module.Params.state
$check_mode = $module.CheckMode

try {
    # Get current user information
    $user = Get-UserInfo -DistributionName $distribution -Username $name
    $module.Diff.before = $user

    # Handle user removal
    if ($state -eq "absent") {
        if ($user) {
            $removeUserParams = {
                DistributionName = $distribution
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

    $home_path = if ($home_path) {
        $home_path
    } else {
        "/home/$name"
    }
    # TODO: Check if $home_path exist, otherwise write a function to create it and set the module changed

    $authorized_key_path = if ($authorized_key_path) {
        $authorized_key_path
    } else {
        "$home_path/.ssh/authorized_keys"
    }
    # TODO: check if authorized_keys exist, otherwise create it and set module changed

    if (-not $user) {
        $newUserParams = @{
            DistributionName = $distribution
            Username = $name
            CreateHome = $create_home
            UserHome = $home_path
            Shell = $shell
            Password = $password
            Uid = $uid
            WhatIf = $check_mode
        }
        New-User @newUserParams
        $user = Get-UserInfo -DistributionName $distribution -Username $name
        Set-ModuleChanged -Module $module
    }

    # TODO: check individual is difference like UserName, UserHome, Shell, Uid in main
    # TODO: if it is difference from the $user then set and mark Module changed individually
    # TODO: create separate function to update these
    # $updateParams = @{
    #     DistributionName = $distribution
    #     Username = $name
    #     UserHome = $home_path
    #     Shell = $shell
    #     Password = $password
    #     Uid = $uid
    #     user = $user
    #     WhatIf = $check_mode
    # }
    # Update-User @updateParams
    # Set-ModuleChanged -Module $module

    if ($sudo -and $sudo -ne $user.sudo) {
        $setSudoAccessParams = {
            DistributionName = $name
            UserName = $name
            WhatIf = $check_mode
        }
        Set-SudoAccess @setSudoAccessParams
        Set-ModuleChanged -Module $module
    }

    $testHavingAuthorizedKeyParams = {
        DistributionName = $distribution
        AuthorizedKey = $authorized_key
        AuthorizedKeyPath = $authorized_key_path
    }
    $hasAuthorizedKey = Test-HavingAuthorizedKey @testHavingAuthorizedKeyParams # TODO: check if authorized_key file in the path contain authorized_key value

    if ($authorized_key -and -not $hasAuthorizedKey) {
        setAuthorizedKeyParams = {
            DistributionName = $distribution
            AuthorizedKey = $authorized_key
            AuthorizedKeyPath = $authorized_key_path
            WhatIf = $check_mode
        }
        Set-AuthorizedKey @setAuthorizedKeyParams # TODO: append value to the end of authorized_key
        Set-ModuleChanged -Module $module
    }

    if ($generate_host_keys) { # TODO: Remove this option and related function
        $generateHostKeysParams = {
            DistributionName = $distribution
            UserName = $name # TODO: Check if this is required
            KeyPath = $generate_key_path # TODO: default to /etc/ssh/ssh_host_*
            KeysBits = $generate_key_bits # TODO: default to 4096
            KeyType = $generate_key_type # TODO: If this is empty then generate all possible keys
            WhatIf = $check_mode
        }
        Generate-HostKeys @generateHostKeysParams
        Set-ModuleChanged -Module $module
    }

    if ($module.Result.changed) {
        $module.Diff.after = Get-UserInfo -DistributionName $distribution -Username $name
    }

    $module.Result.user = $module.Diff.after

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
