﻿param (
	[Parameter(Mandatory)]
	[string]$AdminUsername,

	[Parameter(Mandatory)]
	[string]$AdminPassword,

	[Parameter(Mandatory)]
	[string]$ADFSsvcusername,

	[Parameter(Mandatory)]
	[string]$ADFSsvcpassword,

	[Parameter(Mandatory)]
	[string]$PFXFilePath,
	
	[Parameter(Mandatory)]
    [string]$PFXPassword,

	[Parameter(Mandatory)]
	[string]$ADFSUrl
)

# FUNCTION DS_WriteLog
#==========================================================================
Function DS_WriteLog {
    <#
        .SYNOPSIS
        Write text to this script's log file
        .DESCRIPTION
        Write text to this script's log file
        .PARAMETER InformationType
        This parameter contains the information type prefix. Possible prefixes and information types are:
            I = Information
            S = Success
            W = Warning
            E = Error
            - = No status
        .PARAMETER Text
        This parameter contains the text (the line) you want to write to the log file. If text in the parameter is omitted, an empty line is written.
        .PARAMETER LogFile
        This parameter contains the full path, the file name and file extension to the log file (e.g. C:\Logs\MyApps\MylogFile.log)
        .EXAMPLE
        DS_WriteLog -InformationType "I" -Text "Copy files to C:\Temp" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing information to the log file
        .Example
        DS_WriteLog -InformationType "E" -Text "An error occurred trying to copy files to C:\Temp (error: $($Error[0]))!" -LogFile "C:\Logs\MylogFile.log"
        Writes a line containing error information to the log file
        .Example
        DS_WriteLog -InformationType "-" -Text "" -LogFile "C:\Logs\MylogFile.log"
        Writes an empty line to the log file
    #>
    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory=$true, Position = 0)][ValidateSet("I","S","W","E","-",IgnoreCase = $True)][String]$InformationType,
        [Parameter(Mandatory=$true, Position = 1)][AllowEmptyString()][String]$Text,
        [Parameter(Mandatory=$false, Position = 2)][String]$LogFile
    )
 
    begin {
    }
 
    process {
        # Create new log file (overwrite existing one should it exist)
        if (! (Test-Path $LogFile) ) {    
            # Note: the 'New-Item' cmdlet also creates any missing (sub)directories as well (works from W7/W2K8R2 to W10/W2K16 and higher)
            New-Item $LogFile -ItemType "file" -force | Out-Null
        }

        $DateTime = (Get-Date -format dd-MM-yyyy) + " " + (Get-Date -format HH:mm:ss)
 
        if ( $Text -eq "" ) {
            Add-Content $LogFile -value ("") # Write an empty line
        } else {
            Add-Content $LogFile -value ($DateTime + " " + $InformationType.ToUpper() + " - " + $Text)
        }
        
        # Besides writing output to the log file also write it to the console
        Write-host "$($InformationType.ToUpper()) - $Text"
    }
 
    end {
    }
}
#==========================================================================

# Variables to edit
$BaseLogDir = $Env:Temp
$PackageName = $($MyInvocation.MyCommand.Name)

# Global variables

$LogDir = (Join-Path $BaseLogDir $PackageName).Replace(" ","_")
$LogFileName = "$($PackageName).log"
$LogFile = Join-path $LogDir $LogFileName

# BEGIN SCRIPT
#==========================================================================
DS_WriteLog "I" "-------------------------------------------------------------------------------------------------" $LogFile
DS_WriteLog "I" "Start script" $LogFile

$wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
$ComputerName = $wmiDomain.PSComputerName
$Subject = $ADFSUrl
$PasswordPFX= ConvertTo-SecureString $PFXPassword –asplaintext –force
$FilepathPFX = $PFXFilePath

$DomainName=$wmiDomain.DomainName
$DomainNetbiosName = $DomainName.split('.')[0]
DS_WriteLog "I" "PARAMETERS ##########################" $LogFile
DS_WriteLog "I" "AdminUsername: $($AdminUsername)" $LogFile
DS_WriteLog "I" "AdminPassword: $($AdminPassword)" $LogFile
DS_WriteLog "I" "ADFSsvcusername: $($ADFSsvcusername)" $LogFile
DS_WriteLog "I" "ADFSsvcpassword: $($ADFSsvcpassword)" $LogFile
DS_WriteLog "I" "PFXFilePath: $($PFXFilePath)" $LogFile
DS_WriteLog "I" "PFXPassword: $($PFXPassword)" $LogFile
DS_WriteLog "I" "ADFSUrl: $($ADFSUrl)" $LogFile
DS_WriteLog "I" "PARAMETERS ##########################" $LogFile

DS_WriteLog "I" "VARIABLES ##########################" $LogFile
DS_WriteLog "I" "Computername: $($Computername)" $LogFile
DS_WriteLog "I" "Subject: $($Subject)" $LogFile
DS_WriteLog "I" "PasswordPFX: $($PasswordPFX)" $LogFile
DS_WriteLog "I" "FilepathPFX: $($FilepathPFX)" $LogFile
DS_WriteLog "I" "DomainName: $($DomainName)" $LogFile
DS_WriteLog "I" "DomainNetbiosName: $($DomainNetbiosName)" $LogFile
DS_WriteLog "I" "VARIABLES ##########################" $LogFile

# Create PSCredentials Object
try{
    DS_WriteLog "I" "Create PSCredentiabls Object" $LogFile
    $SecAdminPw = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($AdminUsername)", $SecAdminPw)
    DS_WriteLog "S" "Domaincreds: $($DomainCreds)" $LogFile
}catch{
    DS_WriteLog "E" "Unable to create PSCredentials Object (error: $($Error[0]))" $LogFile
	throw

}
# Install ADFS Certificate
try{
    DS_WriteLog "I" "Install ADFS Certificate from location $FilepathPFX" $LogFile
    $cert = Import-PfxCertificate -FilePath $FilepathPFX -CertStoreLocation Cert:\LocalMachine\My -Password $PasswordPFX
    DS_WriteLog "S" "Successfully installed certificate: $cert" $LogFile
}catch{
    DS_WriteLog "E" "Unable to install ADFS Certificate (error: $($Error[0]))" $LogFile
	throw

}

#Configure ADFS Farm
try{
    DS_WriteLog "I" "Configure ADFS Farm" $LogFile
    Import-Module ADFS
    $wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
    $ComputerName = $wmiDomain.PSComputerName
    $DomainName=$wmiDomain.DomainName
    $DomainNetbiosName = $DomainName.split('.')[0]

    $SecadfsPw = ConvertTo-SecureString $ADFSsvcpassword -AsPlainText -Force
    [System.Management.Automation.PSCredential]$ADFSSvcCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($ADFSsvcusername)", $SecadfsPw)

    $Index = $ComputerName.Substring($ComputerName.Length-1,1)

    try {
        DS_WriteLog "I" "Check if ADFS Farm already exists" $LogFile
        Get-ADfsProperties -ErrorAction Stop
        DS_WriteLog "W" "Farm already exists" $LogFile
    }
    catch {
        DS_WriteLog "I" "No Farm exists, try to create it" $LogFile
        $adfsfarm = Install-AdfsFarm `
            -CertificateThumbprint $cert.thumbprint `
            -FederationServiceName $ADFSUrl `
            -FederationServiceDisplayName "ADFS $Index" `
            -ServiceAccountCredential $ADFSSvcCreds `
            -OverwriteConfiguration

        # Enable Signon Page https://blogs.technet.microsoft.com/rmilne/2017/06/20/how-to-enable-idpinitiatedsignon-page-in-ad-fs-2016/
        Set-AdfsProperties –EnableIdpInitiatedSignonPage $True

        DS_WriteLog "S" "Successfully installed ADFS Farm $adfsfarm" $LogFile
    }
}catch{
    DS_WriteLog "E" "Unable to install ADFS Farm (error: $($Error[0]))" $LogFile
	throw

}

# Install AAD Tools
try{
    DS_WriteLog "I" "Install PowerShell Modules" $LogFile
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name MSOnline -Force
    Install-Module -Name AzureAD -Force
    Install-Module -Name AzureADPreview -AllowClobber -Force
    DS_WriteLog "S" "Successfully installed PowerShell Modules" $LogFile
}catch{
    DS_WriteLog "E" "Unable to install ADFS Farm (error: $($Error[0]))" $LogFile
}