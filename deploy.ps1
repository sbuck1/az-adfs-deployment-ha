﻿$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

#BASIC VARIABLES
    
    $date = $startTime.ToString('yyyy-MM-dd')
    $scriptroot=Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $scriptname=$MyInvocation.MyCommand.Name

#END BASIC VARIABLES

Import-Module Az -ErrorAction SilentlyContinue


#DEPLOYMENT OPTIONS

    $DeploymentName          = "az-adfs-deployment-ha"
    $ConfigFileFolder        = "$scriptroot"
    $ConfigFileName          = "$DeploymentName.xml"
    $ConfigFileFullPath      = "$ConfigFileFolder\$ConfigFileName"
    $LogFolder               = "$scriptroot\_Logs\"
    $LogFileName             = "$date.log"
    $LogFileFullPath         = "$LogFolder\$LogFileName"
    $templateFileADFS        = "$scriptroot\$($DeploymentName)_ADFS.json"
    $templateFileWAP        = "$scriptroot\$($DeploymentName)_WAP.json"

    # GITHUB SETTINGS
    $Branch                  = "master"
    $GitAssetLocation           = "https://raw.githubusercontent.com/sbuck1/$DeploymentName/$Branch/"
    $AssetLocation = "$scriptroot"

#END DEPLOYMENT OPTIONS

#Import Config File


try {
    [xml]$ConfigFileContent = (Get-Content $ConfigFileFullPath)

} catch {

    Exit 1
}

try {
    $Username = $ConfigFileContent.Settings.Azure.AzureAdminUserName
    $password = get-content $($ConfigFileContent.Settings.Azure.CredentialFilePath) | convertto-securestring
    $credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username,$password
    
    Add-AzAccount -Credential $credentials
    # select subscription
    Select-AzSubscription -SubscriptionID $ConfigFileContent.settings.azure.SubscriptionID

} catch {
    $error[0].Exception
    Exit 1
}

# Create a unique deployment number, in case of a deployment extension failed, the script will force the extension again.
# https://dzone.com/articles/completing-your-automated-vm-deployments-with-the

$guid = [guid]::NewGuid()
$guid = [string]$guid
$guid = $guid.Replace("-", "")


#SET UP AZURE PARAMETERS

$deployparmsADFS=@{
    "BaseNetRGName"              = $ConfigFileContent.Settings.Azure.BaseNetResourceGroupName
    "RGNameADFS"                 = $ConfigFileContent.Settings.Azure.ResourceGroupNameADFS
    "RGLocation"                 = $ConfigFileContent.Settings.Azure.ResourceGroupLocation
    "VNetName"                   = $ConfigFileContent.Settings.vNet.Name       
    "VNetAddress"                = $ConfigFileContent.Settings.vNet.Address  
    "ADFSSubnetName"            = $ConfigFileContent.Settings.VMs.ADFS.Conf.Subnet.Name
    "ADFSSubnetAddress"         = $ConfigFileContent.Settings.VMs.ADFS.Conf.Subnet.Address
    "ADFSDNSIP"                 = $ConfigFileContent.Settings.VMs.ADFS.Conf.DNS.IP
    "ADFSVMSize"                = $ConfigFileContent.Settings.VMs.ADFS.Conf.VMSize
    "ADFSVMSKU"                 = $ConfigFileContent.Settings.VMs.ADFS.Conf.SKU
    "ADFS1Name"                  = $ConfigFileContent.Settings.VMs.ADFS.SRV1.Name
    "ADFS1IPAddress"             = $ConfigFileContent.Settings.VMs.ADFS.SRV1.IPAddress
    "ADFS2Name"                  = $ConfigFileContent.Settings.VMs.ADFS.SRV2.Name
    "ADFS2IPAddress"             = $ConfigFileContent.Settings.VMs.ADFS.SRV2.IPAddress
    "DomainFQDN"                 = $ConfigFileContent.Settings.Domain.FQDN
    "DomainNETBIOS"              = $ConfigFileContent.Settings.Domain.NETBIOS
    "OUPath"                     = $ConfigFileContent.Settings.Domain.OU
    "LocalAdminUsername"         = $ConfigFileContent.Settings.Credentials.LocalAdmin.Username
    "LocalAdminPassword"         = $ConfigFileContent.Settings.Credentials.LocalAdmin.Password
    "DomainJoinUsername"         = $ConfigFileContent.Settings.Credentials.DomainJoin.Username
    "DomainJoinPassword"         = $ConfigFileContent.Settings.Credentials.DomainJoin.Password
    "ADFSUrl"                    = $ConfigFileContent.Settings.ADFSConf.URL
    "CertFolderPath"             = $ConfigFileContent.Settings.ADFSConf.CertFolderPath
    "ADFSSvcUsername"            = $ConfigFileContent.Settings.ADFSConf.ServiceAccount.Username
    "ADFSSvcPassword"            = $ConfigFileContent.Settings.ADFSConf.ServiceAccount.Password
    "PFXFilePath"                = $ConfigFileContent.Settings.ADFSConf.PFXFilePath
    "PFXPassword"                = $ConfigFileContent.Settings.ADFSConf.PXFPassword
    "nesteddomainjoinurl"        = "$($GitAssetLocation)nestedtemplates/az-domain-join.json"
    "adfsDSCConfigurationurl"    = "$($GitAssetLocation)DSC/adfsDSCConfiguration.zip"
    "DeployADFSFarmTemplateName" = "InstallADFS.ps1"
    "DeployADFSFarmTemplateUri"  = "$($GitAssetLocation)Scripts/InstallADFS.ps1"
    "DscExtensionUpdateTagVersion" = $guid
}
$deployparmsWAP=@{
    "BaseNetRGName"              = $ConfigFileContent.Settings.Azure.BaseNetResourceGroupName
    "RGNameWAP"                  = $ConfigFileContent.Settings.Azure.ResourceGroupNameWAP
    "RGLocation"                 = $ConfigFileContent.Settings.Azure.ResourceGroupLocation
    "VNetName"                   = $ConfigFileContent.Settings.vNet.Name       
    "VNetAddress"                = $ConfigFileContent.Settings.vNet.Address  
    "WAP1SubnetName"             = $ConfigFileContent.Settings.VMs.WAP.Conf.Subnet.Name
    "WAP1SubnetAddress"          = $ConfigFileContent.Settings.VMs.WAP.Conf.Subnet.Address
    "WAP1VMSize"                 = $ConfigFileContent.Settings.VMs.WAP.Conf.VMSize
    "WAP1VMSKU"                  = $ConfigFileContent.Settings.VMs.WAP.Conf.SKU
    "WAP1Name"                   = $ConfigFileContent.Settings.VMs.WAP.SRV1.Name
    "WAP1IPAddress"              = $ConfigFileContent.Settings.VMs.WAP.SRV1.IPAddress
    "WAP2Name"                   = $ConfigFileContent.Settings.VMs.WAP.SRV2.Name
    "WAP2IPAddress"              = $ConfigFileContent.Settings.VMs.WAP.SRV2.IPAddress
    "DomainFQDN"                 = $ConfigFileContent.Settings.Domain.FQDN
    "DomainNETBIOS"              = $ConfigFileContent.Settings.Domain.NETBIOS
    "OUPath"                     = $ConfigFileContent.Settings.Domain.OU
    "LocalAdminUsername"         = $ConfigFileContent.Settings.Credentials.LocalAdmin.Username
    "LocalAdminPassword"         = $ConfigFileContent.Settings.Credentials.LocalAdmin.Password
    "DomainJoinUsername"         = $ConfigFileContent.Settings.Credentials.DomainJoin.Username
    "DomainJoinPassword"         = $ConfigFileContent.Settings.Credentials.DomainJoin.Password
    "ADFSUrl"                    = $ConfigFileContent.Settings.ADFSConf.URL
    "CertFolderPath"             = $ConfigFileContent.Settings.ADFSConf.CertFolderPath
    "ADFSSvcUsername"            = $ConfigFileContent.Settings.ADFSConf.ServiceAccount.Username
    "ADFSSvcPassword"            = $ConfigFileContent.Settings.ADFSConf.ServiceAccount.Password
    "PFXFilePath"                = $ConfigFileContent.Settings.ADFSConf.PFXFilePath
    "PFXPassword"                = $ConfigFileContent.Settings.ADFSConf.PXFPassword
    "nesteddomainjoinurl"        = "$($GitAssetLocation)nestedtemplates/az-domain-join.json"
    "wapDSCConfigurationurl"     = "$($GitAssetLocation)DSC/wapDSCConfiguration.zip"
    "DeployWAPFarmTemplateName" = "InstallWAP.ps1"
    "DeployWAPFarmTemplateUri"  = "$($GitAssetLocation)Scripts/InstallWAP.ps1"
    "DscExtensionUpdateTagVersion" = $guid
}

#Create Variables from the Hashtable
foreach($param in $deployparms.GetEnumerator()){new-variable -name $param.name -value $param.value -ErrorAction SilentlyContinue}

#END SET UP AZURE PARAMETERS


try {
    Get-AzResourceGroup -Name $RGNameADFS -ErrorAction Stop
    Write-Host "Resource group $RGNameADFS exists, updating deployment"
}
catch {
    New-AzResourceGroup -Name $RGNameADFS -Location $RGLocation
    Write-Host "Created new resource group $RGNameADFS."
}
try {
    Get-AzResourceGroup -Name $RGNameWAP -ErrorAction Stop
    Write-Host "Resource group $RGNameWAP exists, updating deployment"
}
catch {
    New-AzResourceGroup -Name $RGNameWAP -Location $RGLocation
    Write-Host "Created new resource group $RGNameWAP."
}

$version ++

try{
    
    $deploymentADFS = New-AzResourceGroupDeployment -ResourceGroupName $RGNameADFS -TemplateParameterObject $deployparmsADFS -TemplateFile $TemplateFileADFS -Name "$DeploymentName$version" -AsJob
    $deploymentWAP = New-AzResourceGroupDeployment -ResourceGroupName $RGNameWAP -TemplateParameterObject $deployparmsWAP -TemplateFile $TemplateFileWAP -Name "$DeploymentName$version" -whatif

}catch{
    $error[0].Exception

}
$endTime=Get-Date

Write-Host ""
Write-Host "Total Deployment time:"
New-TimeSpan -Start $startTime -End $endTime | Select Hours, Minutes, Seconds

# FINALIZE

# Get the public ip address of the WAP LoadBalancer
$PiP = Get-AzureRmPublicIpAddress -ResourceGroupName $RGName | Select-Object ipaddress
$Pip = $Pip.IPAddress

# Update your hosts file or public DNS with the following settings:
write-host "Update your hosts file or public DNS with the following settings:"
write-host "DNS Name  :   $ADFSUrl"
write-host "IP        :   $Pip" 