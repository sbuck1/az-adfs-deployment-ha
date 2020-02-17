Configuration Main
{
    Param 
    ( 
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [String]$CertFolderPath,

        [Parameter(Mandatory)]
        [String]$PFXFilePath,

        [Parameter(Mandatory)]
        [String]$PFXThumbprint,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$PFXPassword,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    $wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
    $shortDomain = $wmiDomain.DomainName
    $PasswordPFX = $PFXPassword
    $ThumbprintPFX = $PFXThumbprint
    $FilePathPFX = $PFXFilePath

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName CertificateDsc

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${shortDomain}\$($AdminCreds.UserName)", $AdminCreds.Password)
    
    #Download AADConnect
    New-Item -Path "C:\Install"-ItemType Directory -Force
    Invoke-WebRequest "https://download.microsoft.com/download/B/0/0/B00291D0-5A83-4DE7-86F5-980BC00DE05A/AzureADConnect.msi" -OutFile "C:\Install\AzureADConnect.msi"

    #Install Certificate
    Import-PfxCertificate -FilePath $FilePathPFX -CertStoreLocation Cert:\LocalMachine\My -Password $($PasswordPFX.Password)

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

    }
}
