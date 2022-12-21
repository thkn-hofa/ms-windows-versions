# ms-windows-versions

Everyday a Github action is run to automatically update the file [ms-windows-server-versions.json](./lists/ms-windows-server-versions.json) with data published on these Microsoft sites: 

* https://support.microsoft.com/en-gb/topic/december-13-2022-kb5021249-os-build-20348-1366-d5fe7608-bc9d-4055-a88c-fb2fd3d5fd45
* https://support.microsoft.com/en-us/topic/windows-10-and-windows-server-2019-update-history-725fc2e1-4443-6831-a5ca-51ff5cbcb059

This will list only server 2016 and higher because lower versions didn't work with these 'logical' build numbers yet.

## Current version and build

This snippit gets you the current version and build

```powershell
# Create Registry Object
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', 'localhost')

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

    # You can change all the KB numbers to help page links with this
    Foreach ($PC in ($Versions | Get-Member -MemberType NoteProperty).Name) {
        Foreach ($Build in $Versions.$PC) {
            $Build.KB =  "https://support.microsoft.com/en-us/help/{0}" -f ($Build.KB -replace "^KB")
        }
    }

    # Return the information for this version and build
    $CurrentVersion = $Versions.$ProductCode | ? { $_.Build -eq $BuildVersion.ToString(2) }
    "`nCurrent version of Windows Server {0}`n" -f $Productcode
    ($CurrentVersion | Format-List | Out-String).Trim()

    # Get the latest build for this 'product code'
    $LatestVersion = $Versions.$Productcode | Sort Date | Select -Last 1
    "`nLatest version of Windows Server {0}`n" -f $Productcode
    ($LatestVersion | Format-List | Out-String).Trim()
}
```