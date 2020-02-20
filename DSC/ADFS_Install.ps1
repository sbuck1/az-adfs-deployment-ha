Configuration Main
{
    Param 
    ( 
        [Parameter(Mandatory)]
        [string]$ADFSRole,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$ADFSSvcCreds,

        [Parameter(Mandatory)]
        [string]$PFXFilePath,

        [Parameter(Mandatory)]
        [string]$PFXThumbprint,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$PFXPassword,

        [Parameter(Mandatory)]
        [string]$ADFSUrl,
        
        [Parameter(Mandatory)]
        [string]$PrimaryADFSServer,
        
        [Parameter(Mandatory)]
	    [string]$SecondaryADFSServer,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

$MyData =
@{
    AllNodes =
    @(
        @{
            NodeName = $PrimaryADFSServer
            ADFSRole = $ADFSRole
        },


        @{
            NodeName = $SecondaryADFSServer
            ADFSRole = $ADFSRole
        }
    );
}
    
write-output $MyData
$MyData | Out-File C:\WindowsAzure\test.txt

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xCertificate

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name MSOnline -Force
    Install-Module -Name AzureAD -Force
    Install-Module -Name AzureADPreview -AllowClobber -Force

    Node $AllNodes.Where{$_.ADFSRole -eq "Primary"}.NodeName
    {
        LocalConfigurationManager            
        {            
            DebugMode = 'All'
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true
        }
        WindowsFeature installADFS  #install ADFS
        {
            Ensure = "Present"
            Name   = "ADFS-Federation"
        }
        xPfxImport ADFSCert
        {
            Thumbprint = $PFXThumbprint
            Path       = $PFXFilePath
            Location   = 'LocalMachine'
            Store      = 'My'
            Credential = $PFXPassword
        }
        Script JoinADFSFarm
        {
            SetScript = {
                
                Add-AdfsFarmNode `
                    -Credential $DomainCreds `
                    -PrimaryComputerName $PrimaryADFSServer `
                    -PrimaryComputerPort 80 `
                    -ServiceAccountCredential $ADFSSvcCreds `
                    -CertificateThumbprint $PFXThumbprint `
                    -Erroraction Stop
            }
            TestScript = {
                $ADFSFarm = Get-ADFSFarmInformation -ErrorAction SilentlyContinue
                if($ADFSFarm){return $True}
                else{return $False}
            }
            GetScript = {
                $ADFSFarm = Get-ADFSFarmInformation -ErrorAction SilentlyContinue
                return @{Result = $ADFSFarm}
            }
            DependsOn = '[xPfxImport]ADFSCert'
        }
    }

    Node $AllNodes.Where{$_.ADFSRole -eq "Secondary"}.NodeName
    {
        LocalConfigurationManager            
        {            
            DebugMode = 'All'
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true
        }
        WindowsFeature installADFS  #install ADFS
        {
            Ensure = "Present"
            Name   = "ADFS-Federation"
        }
        xPfxImport ADFSCert
        {
            Thumbprint = $PFXThumbprint
            Path       = $PFXFilePath
            Location   = 'LocalMachine'
            Store      = 'My'
            Credential = $PFXPassword
        }
        Script JoinADFSFarm
        {
            SetScript = {
                
                Add-AdfsFarmNode `
                    -Credential $DomainCreds `
                    -PrimaryComputerName $PrimaryADFSServer `
                    -PrimaryComputerPort 80 `
                    -ServiceAccountCredential $ADFSSvcCreds `
                    -CertificateThumbprint $PFXThumbprint `
                    -Erroraction Stop
            }
            TestScript = {
                $ADFSFarm = Get-ADFSFarmInformation -ErrorAction SilentlyContinue
                if($ADFSFarm){return $True}
                else{return $False}
            }
            GetScript = {
                $ADFSFarm = Get-ADFSFarmInformation -ErrorAction SilentlyContinue
                return @{Result = $ADFSFarm}
            }
            DependsOn = '[xPfxImport]ADFSCert'
        }
    }
}
