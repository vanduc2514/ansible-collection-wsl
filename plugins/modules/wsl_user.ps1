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
        ssh_key = @{
            type     = "str"
        }
        ssh_key_file = @{
            type     = "path"
        }
        generate_ssh_key = @{
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
        ,@("ssh_key", "ssh_key_file")
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
    $gidMatch = $result -match "gid=(\d+)\(([^)]+)\)"
    $groupsMatch = $result -match "groups=([^$]*)"

    $uid = if ($uidMatch) { [int]$Matches[1] } else { $null }
    $gid = if ($gidMatch) { [int]$Matches[1] } else { $null }
    $primaryGroup = if ($gidMatch) { $Matches[2] } else { $null }

    $groups = @()
    if ($groupsMatch) {
        $groupsString = $Matches[1]
        $groupMatches = [regex]::Matches($groupsString, "\d+\(([^)]+)\)")
        foreach ($match in $groupMatches) {
            $groups += $match.Groups[1].Value
        }
    }

    # Get home directory
    $homeCmd = "getent passwd $Username 2>/dev/null | cut -d: -f6 || echo ''"
    $home = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $homeCmd

    # Get shell
    $shellCmd = "getent passwd $Username 2>/dev/null | cut -d: -f7 || echo ''"
    $shell = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $shellCmd

    # Get comment/gecos
    $commentCmd = "getent passwd $Username 2>/dev/null | cut -d: -f5 || echo ''"
    $comment = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $commentCmd

    # Check sudo status
    $sudoCmd = "grep -q '^$Username\\s\\+ALL\\s*=' /etc/sudoers 2>/dev/null || [ -f /etc/sudoers.d/$Username ] && echo 'true' || echo 'false'"
    $sudo = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sudoCmd).Trim() -eq "true"

    # Check SSH authorized_keys if home directory exists
    $sshKeyCmd = "test -f '$home/.ssh/authorized_keys' && cat '$home/.ssh/authorized_keys' || echo ''"
    $sshKey = Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $sshKeyCmd

    return @{
        name = $Username
        uid = $uid
        gid = $gid
        group = $primaryGroup
        groups = $groups
        home = $home
        shell = $shell
        comment = $comment
        sudo = $sudo
        authorized_key = $sshKey
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

        [string]
        $Comment = "",

        [bool]
        $CreateHome = $true,

        [string]
        $Home,

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
    } elseif ($Home) {
        $usercmd += " --home-dir '$Home'"
        # Create the directory if it doesn't exist
        $mkdirCmd = "mkdir -p '$Home'"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Create home directory: $Home")) {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $mkdirCmd | Out-Null
        }
    }

    if ($Shell) {
        $usercmd += " --shell '$Shell'"
    }

    if ($Comment) {
        $usercmd += " --comment '$Comment'"
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
        $Comment,

        [string]
        $Home,

        [string]
        $Shell,

        [string]
        $Password,

        [int]
        $Uid,

        [hashtable]
        $CurrentUser
    )

    # Build usermod command
    $usercmd = "usermod"
    $changes = $false

    if ($Comment -and $Comment -ne $CurrentUser.comment) {
        $usercmd += " --comment '$Comment'"
        $changes = $true
    }

    if ($Home -and $Home -ne $CurrentUser.home) {
        $usercmd += " --home '$Home' --move-home"
        $changes = $true

        # Create the directory if it doesn't exist
        $mkdirCmd = "mkdir -p '$Home'"
        if ($PSCmdlet.ShouldProcess($DistributionName, "Create home directory: $Home")) {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $mkdirCmd | Out-Null
        }
    }

    if ($Shell -and $Shell -ne $CurrentUser.shell) {
        $usercmd += " --shell '$Shell'"
        $changes = $true
    }

    if ($Uid -and $Uid -ne $CurrentUser.uid) {
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

function Set-SSHAuthorizedKey {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]
        $DistributionName,

        [string]
        $Username,

        [string]
        $Key,

        [string]
        $HomeDir
    )

    if (-not $Key) {
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
    $keyNormalized = $Key.Trim()

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

function Generate-SSHKey {
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
    $sshKeyPath = if ($KeyPath) { $KeyPath } else { "$HomeDir/.ssh/id_rsa" }

    # Check if key already exists
    $checkKeyCmd = "test -f '$sshKeyPath' && echo 'EXISTS' || echo 'NOT_EXISTS'"
    $keyExists = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $checkKeyCmd).Trim() -eq "EXISTS"

    if ($keyExists) {
        return @{
            changed = $false
            key_path = $sshKeyPath
            public_key_path = "$sshKeyPath.pub"
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
    $generateKeyCmd = "ssh-keygen -t rsa -b 4096 -f '$sshKeyPath' -N '' -C '$Username@wsl' && chmod 600 '$sshKeyPath' && chmod 644 '$sshKeyPath.pub' && chown -R ${Username}:${Username} '$HomeDir/.ssh'"
    if ($PSCmdlet.ShouldProcess($DistributionName, "Generate SSH key for user: $Username")) {
        try {
            Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $generateKeyCmd | Out-Null

            # Add to authorized_keys if not already there
            $pubKeyCmd = "cat '$sshKeyPath.pub'"
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
                key_path = $sshKeyPath
                public_key_path = "$sshKeyPath.pub"
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

function Remove-WSLUser {
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

$name = $module.Params.name
$distribution = $module.Params.distribution
$comment = $module.Params.comment
$create_home = $module.Params.create_home
$home = $module.Params.home
$shell = $module.Params.shell
$password = $module.Params.password
$ssh_key = $module.Params.ssh_key
$ssh_key_file = $module.Params.ssh_key_file
$generate_ssh_key = $module.Params.generate_ssh_key
$ssh_key_path = $module.Params.ssh_key_path
$uid = $module.Params.uid
$sudo = $module.Params.sudo
$state = $module.Params.state
$check_mode = $module.CheckMode

# Read SSH key from file if specified
if ($ssh_key_file) {
    try {
        $ssh_key = Get-Content -Path $ssh_key_file -Raw
    } catch {
        $module.FailJson("Failed to read SSH key file: $($_.Exception.Message)", $_)
    }
}

try {
    # Check if the distribution exists
    $distro = Get-WSLDistribution -DistributionName $distribution
    if (-not $distro) {
        $module.FailJson("WSL distribution '$distribution' not found")
    }

    # Check if distribution is running, if not, start it
    if ($distro.state -ne "Running") {
        if (-not $check_mode) {
            $linuxCommand = "sleep infinity"
            Invoke-LinuxCommandInBackground -DistributionName $distribution -LinuxCommand $linuxCommand

            # Wait for distribution to start
            $startTime = Get-Date
            $timeout = New-TimeSpan -Seconds 30
            do {
                Start-Sleep -Seconds 1
                $distro = Get-WSLDistribution -DistributionName $distribution
                if ((Get-Date) - $startTime -gt $timeout) {
                    $module.FailJson("Timeout waiting for WSL distribution '$distribution' to start")
                }
            } while ($distro.state -ne "Running")
        }
    }

    # Get current user information
    $currentUser = Get-UserInfo -DistributionName $distribution -Username $name
    $module.Diff.before = $currentUser

    # Handle user removal
    if ($state -eq "absent") {
        if ($currentUser) {
            if (-not $check_mode) {
                # Use --remove option to remove home directory too
                Remove-WSLUser -DistributionName $distribution -Username $name -RemoveHome $true
            }
            $module.Result.changed = $true
            $module.Diff.after = $null
        }
        $module.ExitJson()
    }

    # Set default home directory path if not specified
    if (-not $home -and $create_home) {
        $home = "/home/$name"
    }

    # Create or update user
    if (-not $currentUser) {
        # Create new user
        if (-not $check_mode) {
            $newUserParams = @{
                DistributionName = $distribution
                Username = $name
                Comment = $comment
                CreateHome = $create_home
                Home = $home
                Shell = $shell
                Password = $password
                Uid = $uid
            }
            New-User @newUserParams

            # Get updated user info for diff
            $currentUser = Get-UserInfo -DistributionName $distribution -Username $name

            # Handle sudo access
            if ($sudo) {
                Set-SudoAccess -DistributionName $distribution -Username $name -Sudo $sudo -CurrentSudo $false
            }

            # Handle SSH key
            if ($ssh_key) {
                Set-SSHAuthorizedKey -DistributionName $distribution -Username $name -Key $ssh_key -HomeDir $currentUser.home
            }

            # Generate SSH key if requested
            if ($generate_ssh_key) {
                $sshKeyResult = Generate-SSHKey -DistributionName $distribution -Username $name -HomeDir $currentUser.home -KeyPath $ssh_key_path
                $module.Result.ssh_key_result = $sshKeyResult
            }
        }
        $module.Result.changed = $true
    } else {
        # Update existing user
        $changes = $false

        if (-not $check_mode) {
            # Update user properties
            $updateParams = @{
                DistributionName = $distribution
                Username = $name
                Comment = $comment
                Home = $home
                Shell = $shell
                Password = $password
                Uid = $uid
                CurrentUser = $currentUser
            }
            $userChanged = Update-User @updateParams

            # Update sudo access
            $sudoChanged = Set-SudoAccess -DistributionName $distribution -Username $name -Sudo $sudo -CurrentSudo $currentUser.sudo

            # Update SSH authorized key
            $homeDir = if ($home) { $home } else { $currentUser.home }
            $sshChanged = if ($ssh_key) {
                Set-SSHAuthorizedKey -DistributionName $distribution -Username $name -Key $ssh_key -HomeDir $homeDir
            } else {
                $false
            }

            # Generate SSH key if requested
            if ($generate_ssh_key) {
                $homeDir = if ($home) { $home } else { $currentUser.home }
                $sshKeyResult = Generate-SSHKey -DistributionName $distribution -Username $name -HomeDir $homeDir -KeyPath $ssh_key_path
                $module.Result.ssh_key_result = $sshKeyResult
                $sshKeyGenChanged = $sshKeyResult.changed
            } else {
                $sshKeyGenChanged = $false
            }

            $changes = $userChanged -or $sudoChanged -or $sshChanged -or $sshKeyGenChanged
        }

        $module.Result.changed = $changes
    }

    # Get final user info for diff
    if ($module.Result.changed -and -not $check_mode) {
        $module.Diff.after = Get-UserInfo -DistributionName $distribution -Username $name
    } else {
        $module.Diff.after = $currentUser
    }

    # Set the user result
    $module.Result.user = $module.Diff.after

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()
