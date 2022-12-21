# ms-windows-versions

[![Update MS Windows versions dictionary](https://github.com/thkn-hofa/ms-windows-versions/actions/workflows/main.yml/badge.svg)](https://github.com/thkn-hofa/ms-windows-versions/actions/workflows/main.yml)

Everyday a Github action is run to automatically update the file [ms-windows-server-versions.json](./lists/ms-windows-server-versions.json) with data published on these Microsoft sites: 

* https://support.microsoft.com/en-gb/topic/december-13-2022-kb5021249-os-build-20348-1366-d5fe7608-bc9d-4055-a88c-fb2fd3d5fd45
* https://support.microsoft.com/en-us/topic/windows-10-and-windows-server-2019-update-history-725fc2e1-4443-6831-a5ca-51ff5cbcb059

This will list only server 2016 and higher because lower versions didn't work with these 'logical' build numbers yet.

# Current version and build

Running ```Get-CurrentWindowsServerVersion.ps1``` will query the registry and the automatically generated list in this repository to get the current build version and date for a Windows Server.
