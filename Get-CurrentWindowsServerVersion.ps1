Param (
    [Parameter(Mandatory=$False, Position=0, ValueFromPipeline=$True)]
    [String]$Server = "localhost"
)

# Create Registry Object
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Server)

# Get current OS version (10.0 = Server 2016 and higher)
$CurrentVersion = New-Object Version($reg.opensubkey("SOFTWARE\\Microsoft\\Windows NT\\Currentversion").GetValue("CurrentMajorVersionNumber"), $reg.opensubkey("SOFTWARE\\Microsoft\\Windows NT\\Currentversion").GetValue("CurrentMinorVersionNumber"))

If ($CurrentVersion -eq "0.0") {
    # Server 2012 R2 or lower
    Throw "This server is version 2012 R2 or lower"
}
Else {
    # Get Product Name (Server 2016 / 2019 / 2022)
    $Productname = $reg.opensubkey("SOFTWARE\\Microsoft\\Windows NT\\Currentversion").GetValue("ProductName")

    # Get Product Code (2019 has 5 different 'Product codes': 1809 / 1903 / 1909 / 2004 / 20H2) 
    If ($Productname -match "2019") {
        $Productcode = $reg.opensubkey("SOFTWARE\\Microsoft\\Windows NT\\Currentversion").GetValue("ReleaseID")
    }
    # If not server 2019, just get the digits of the whole string (2016 or 2022)
    Else {
        $Productcode = $Productname -replace "[\D]"
    }

    # Get the build version
    $BuildVersion = New-Object Version($reg.opensubkey("SOFTWARE\\Microsoft\\Windows NT\\Currentversion").GetValue("CurrentBuildNumber"), $reg.opensubkey("SOFTWARE\\Microsoft\\Windows NT\\Currentversion").GetValue("UBR"))

    # Download the list of windows server versions from GitHub
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Versions = (Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/thkn-hofa/ms-windows-versions/main/lists/ms-windows-server-versions.json").Content | ConvertFrom-Json

    # # You can change all the KB numbers to help page links with this
    # Foreach ($PC in ($Versions | Get-Member -MemberType NoteProperty).Name) {
    #     Foreach ($Build in $Versions.$PC) {
    #         $Build.KB =  "https://support.microsoft.com/en-us/help/{0}" -f ($Build.KB -replace "^KB")
    #     }
    # }

    # Return the information for this version and build
    $CurrentVersion = $Versions.$ProductCode | ? { $_.Build -eq $BuildVersion.ToString(2) }
    "`nCurrent version of Windows Server {0}`n" -f $Productcode
    ($CurrentVersion | Format-List | Out-String).Trim()
}