Configuration Main
{
    Param 
    ( 
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
        
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xCertificate
    
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name MSOnline -Force
    Install-Module -Name AzureAD -Force
    Install-Module -Name AzureADPreview -AllowClobber -Force

    Node localhost
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
        Script CreateADFSFarm
        {
            SetScript = {
                Import-Module ADFS
                "SetScript" | Out-File C:\windowsazure\Setscript.txt
                Install-AdfsFarm `
                    -Credential $DomainCreds `
                    -CertificateThumbprint $PFXThumbprint `
                    -FederationServiceName $ADFSUrl `
                    -FederationServiceDisplayName "ADFS" `
                    -ServiceAccountCredential $ADFSSvcCreds `
                    -OverwriteConfiguration
            }
            TestScript = {
                Import-Module ADFS
                "TESTScript" | Out-File C:\windowsazure\testscript.txt
                $ADFSFarm = Get-ADFSFarmInformation -ErrorAction SilentlyContinue
                if($ADFSFarm){return $True}
                else{return $False}
            }
            GetScript = {
                Import-Module ADFS
                "GetScript" | Out-File C:\windowsazure\Getscript.txt
                $ADFSFarm = Get-ADFSFarmInformation -ErrorAction SilentlyContinue
                return @{Result = $ADFSFarm}
            }
            DependsOn = '[xPfxImport]ADFSCert'
        }

    }
}
