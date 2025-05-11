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

function Test-FileExist {
    param(
        [string]
        $DistributionName,

        [string]
        $Path
    )

    return Test-WSLFileExist -DistributionName $DistributionName -Path $Path
}

######################################### Main ##########################################

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$distribution_name = $module.Params.distribution
$path = $module.Params.path

try {
    $exists = Test-FileExist -DistributionName $distribution_name -Path $path

    $module.Result.path = $path
    $module.Result.exists = $exists

} catch {
    $module.FailJson("An error occurred: $($_.Exception.Message)", $_)
}

$module.ExitJson()