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
        path = @{
            type     = "str"
            required = $true
        }
    }
    supports_check_mode = $true
}

function Get-FileContent {
    param(
        [string]
        $DistributionName,

        [string]
        $Path
    )

    if (-not $(Test-WSLFileExist -DistributionName $DistributionName -Path $Path)) {
        throw "File '$Path' not found in WSL distribution '$DistributionName'"
    }

    # Check if it's a directory
    $isDirectoryCmd = "test -d '$Path' && echo 'true' || echo 'false'"
    $isDirectory = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $isDirectoryCmd).Trim() -eq "true"

    if ($isDirectory) {
        throw "Path '$Path' is a directory, not a file"
    }

    # Get file metadata
    $ownerCmd = "stat -c '%U' '$Path' 2>/dev/null || echo ''"
    $owner = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $ownerCmd).Trim()

    $modeCmd = "stat -c '%a' '$Path' 2>/dev/null || echo ''"
    $mode = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $modeCmd).Trim()

    # Get file content and encode it in base64
    $contentCmd = "cat '$Path' 2>/dev/null | base64 -w 0 || echo ''"
    $content = (Invoke-LinuxCommand -DistributionName $DistributionName -LinuxCommand $contentCmd).Trim()

    return @{
        path = $Path
        content = $content
        owner = $owner
        mode = $mode
    }
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution_name = $module.Params.distribution
$path = $module.Params.path

try {
    $file_info = Get-FileContent -DistributionName $distribution_name -Path $path

    $module.Result.path = $path
    $module.Result.content = $file_info.content
    $module.Result.encoding = "base64"
    $module.Result.owner = $file_info.owner
    $module.Result.mode = $file_info.mode

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()