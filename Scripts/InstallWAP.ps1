param (
	[Parameter(Mandatory)]
	[string]$ADFSsvcusername,

	[Parameter(Mandatory)]
	[string]$ADFSsvcpassword,
	
	[Parameter(Mandatory)]
	[string]$PFXFilePath,
	
	[Parameter(Mandatory)]
	[string]$CertFolderPath,
	
	[Parameter(Mandatory)]
	[string]$DomainFQDN,

	[Parameter(Mandatory)]
	[string]$DomainNETBIOS,
	
	[Parameter(Mandatory)]
    [string]$PFXPassword,

	[Parameter(Mandatory)]
	[string]$ADFSUrl,

	[Parameter(Mandatory)]
	[string]$LoadbalancerAddress
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

$PasswordPFX=ConvertTo-SecureString $PFXPassword –asplaintext –force
$FilepathPFX = $PFXFilePath
$FQDNDomain = $DomainFQDN

# Create PSCredentials Object
try{
	DS_WriteLog "I" "Create PSCredentiabls Object" $LogFile
	$SecadfsPw = ConvertTo-SecureString $ADFSsvcpassword -AsPlainText -Force
	[System.Management.Automation.PSCredential]$ADFSSvcCreds = New-Object System.Management.Automation.PSCredential ("${DomainNETBIOS}\$($ADFSsvcusername)", $SecadfsPw)
	DS_WriteLog "I" "$AdfsSvcCreds" $LogFile
}catch{
	DS_WriteLog "E" "Unable to create PSCredentials Object" $LogFile
	throw

}
$completeFile="c:\temp\prereqsComplete"
md "c:\temp" -ErrorAction Ignore
md "c:\AADLab" -ErrorAction Ignore


# Check if first prerequisites already ran
DS_WriteLog "I" "Check if first prerequisites already ran" $LogFile
if (!(Test-Path -Path "$($completeFile)0")) {
	DS_WriteLog "I" "Run first prerequisites" $LogFile
	$PathToCert= $CertFolderPath
	DS_WriteLog "I" "CertFolderPath: $PathToCert" $LogFile
	DS_WriteLog "I" "ADFSSvcUsername: $Adfssvcusername" $LogFile

	# Copying certificate to WAP Server
	try{
		net use "$PathToCert" $ADFSsvcpassword /USER:$ADFSsvcusername
		DS_WriteLog "I" "Net Use Successful" $LogFile
		Copy-Item -Path "$PathToCert\*.pfx" -Destination "c:\temp\" -Recurse -Force -ErrorAction Stop
		Copy-Item -Path "$PathToCert\*.cer" -Destination "c:\temp\" -Recurse -Force -ErrorAction Stop
		DS_WriteLog "I" "Copied Certificates successful" $LogFile
	}catch{
		DS_WriteLog "E" "Error, copying certificates (error: $($Error[0]))" $LogFile
		throw

	}
    #record that we got this far
    New-Item -ItemType file "$($completeFile)0"
}else{
	DS_WriteLog "I" "First prerequisites already run, skip" $LogFile
}

# Check if second step already ran
DS_WriteLog "I" "Check if first step already ran" $LogFile
if (!(Test-Path -Path "$($completeFile)1")) {
	DS_WriteLog "I" "Run second step" $LogFile
	#install root cert
    $RootFile  = Get-ChildItem -Path "c:\temp\*.cer"
	$RootPath  = $RootFile.FullName
	DS_WriteLog "I" "Install Root Certificate from $RootPath" $LogFile
	try{
		$rootCert  = Import-Certificate -CertStoreLocation Cert:\LocalMachine\Root -FilePath $RootPath
		DS_WriteLog "I" "Successfull installed Root certificate: $rootCert" $LogFile
	}catch{
		DS_WriteLog "I" "Unable to install Root Certificate (error: $($Error[0]))" $LogFile
		throw
	}

	#install the certificate that will be used for ADFS Service
	
	$CertFile  = Get-ChildItem -Path "c:\temp\*.pfx"
	$CertPath  = $CertFile.FullName
	DS_WriteLog "I" "Installing ADFS Certificate from path ($certpath)" $LogFile

	try{
		$cert      = Import-PfxCertificate -Exportable -Password $PasswordPFX -CertStoreLocation cert:\localmachine\my -FilePath $CertPath
		DS_WriteLog "I" "Successfully installed certificate: $cert" $LogFile
		# Check if certificate is a wildcard certificate
		if($cert.Subject -match '\*'){
			$wildcard = $true
		}else{
			$wildcard = $false
		}
		DS_WriteLog "I" "Certificate is wildcard?: $wildcard" $LogFile
		

	}catch{
		DS_WriteLog "I" "Unable to installed adfs certificate (error: $($Error[0]))" $LogFile
	}

	# Add Hosts entry
	DS_WriteLog "I" "Add HOSTS Entry" $LogFile
	If ((Get-Content "$($env:windir)\system32\Drivers\etc\hosts" ) -notcontains "$LoadBalancerAddress $ADFSUrl")   
 		{Add-Content -Encoding UTF8  "$($env:windir)\system32\Drivers\etc\hosts" "$LoadBalancerAddress $ADFSUrl" }	

	
	DS_WriteLog "I" "Using the following certificate for the url ($ADFSUrl): $cert" $LogFile
	DS_WriteLog "I" "Try to install the WebApplication Proxy" $LogFile
	DS_WriteLog "I" "ADFSSvcCreds: $ADFSSvcCreds" $LogFile
	DS_WriteLog "I" "CertThumbprint: $($cert.Thumbprint)" $LogFile
	DS_WriteLog "I" "FederationServiceName: $($ADFSUrl)" $LogFile
	start-sleep 60

	try{
		Install-WebApplicationProxy `
			-FederationServiceTrustCredential $ADFSSvcCreds `
			-CertificateThumbprint $cert.Thumbprint`
			-FederationServiceName $ADFSUrl -ErrorAction Stop
		DS_WriteLog "I" "Successfully installed the WebApplication Proxy" $LogFile
	}catch{
		DS_WriteLog "I" "Unable to install the WebApplication Proxy (error: $($Error[0]))" $LogFile

	}

	# Test if the WebApplication was successfull installed
	DS_WriteLog "I" "Check if the webapplication was successfully installed" $LogFIle
	start-sleep 120
	$WAPProxy = Get-WebApplicationProxyConfiguration -ErrorAction SilentlyContinue
	if(!$WAPProxy){
		DS_WriteLog "I" "No config found, try it again" $LogFile
		try{
			Install-WebApplicationProxy `
			-FederationServiceTrustCredential $ADFSSvcCreds `
			-CertificateThumbprint $cert.Thumbprint`
			-FederationServiceName $ADFSUrl -ErrorAction Stop
			DS_WriteLog "I" "Successfully installed teh WebApplication Proxy" $LogFile
		}catch{

			DS_WriteLog "E" "Unable to install the WebApplication Proxy (error: $($Error[0]))" $LogFile
			throw
		}

	}else{
		DS_WriteLog "I" "Sucessfully installed the WAP Proxy with the following config:" $LogFile
		DS_WriteLog "I" "$WAPProxy" $LogFile
	}

    #record that we got this far
    New-Item -ItemType file "$($completeFile)1"
}
