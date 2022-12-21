Function Get-WindowsServerBuildsList {
    $WindowsVersionUpdateHistoryURIs = @(
        "https://support.microsoft.com/en-us/topic/windows-10-and-windows-server-2019-update-history-725fc2e1-4443-6831-a5ca-51ff5cbcb059"
        "https://support.microsoft.com/en-gb/topic/december-13-2022-kb5021249-os-build-20348-1366-d5fe7608-bc9d-4055-a88c-fb2fd3d5fd45"
    )

    $Versions = [Hashtable]@{}

    Foreach ($URI in $WindowsVersionUpdateHistoryURIs) {
        $x = Invoke-WebRequest -UseBasicParsing -Uri $URI
        $NavLinks = $x.links | ? { $_.class -eq "supLeftNavLink" }

        If ($Null -ne ($NavLinks.Outerhtml | ? { $_ -match "update history" })) {
            $UpdateHistoryNavLinks = $NavLinks | ? { $_.outerHTML -match "Update history" }
        }
        Else {
            $UpdateHistoryNavLinks = $NavLinks | ? { $_.outerHTML -match "Windows Server" } | Select -First 1
        }

        $SectionFirsts = $UpdateHistoryNavLinks | Sort-Object -Unique @{E={([Xml]($_.outerHTML)).a."#text"}},href | Sort-Object @{E={$NavLinks.IndexOf($_)}}
        
        $Sections = [Hashtable][Ordered]@{}
        For ($i=0 ; $i -lt @($SectionFirsts).Count ; $i++) {
            If ($SectionFirsts[$i].outerHTML -match "Server") {
                $FirstChild = $NavLinks.IndexOf($SectionFirsts[$i]) + 1
                If ($i -eq @($SectionFirsts).Count - 1) {
                    $LastChild = $NavLinks.Count - 1
                }
                Else {
                    $LastChild = $NavLinks.IndexOf($SectionFirsts[$i+1]) - 1
                }
                If (($FirstChild..$LastChild).Count -gt 3) {
                    $Sections.Add($SectionFirsts[$i], $NavLinks[$FirstChild..$LastChild])
                    Write-Verbose ("{0}: {1} to {2}" -f ([xml]($SectionFirsts[$i].outerhtml)).a."#text",$FirstChild,$LastChild)
                }
            }
        }

        Foreach ($S in $Sections.Keys) {
            $Title = ([Xml]($s.outerHTML)).a."#text"

            Foreach ($T in @(($Title -split "\band\b") | ? { $_ -match "Server" })) {
                If ($t -match "version") {
                    $Matches = [Regex]::Matches($T,"version (?<version>[\w]+)",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                }
                Else {
                    $Matches = [Regex]::Matches($T,"Server,? (?<version>[\w]+)",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                }
                $VersionNumber = ($Matches.Groups | ? { $_.name -eq "Version"}).Value | Select -Last 1
                Write-Verbose ("{0} - {1}" -f $T, $VersionNumber)
                If ($Versions.Keys -notcontains $VersionNumber) {
                    $Versions.Add($VersionNumber, $(New-Object System.Collections.Generic.List[PSCustomObject]))
                }

                Foreach ($V in ($Sections[$S] | % { ([Xml]($_.outerHTML)).a."#text" })) {
                    # $v
                    $Regex = [Regex]::Matches($V, "(?<date>^[\w\,\s]+).*(?<kb>KB\d+\b).*OS Builds? (?<build>[\d\.]+)")
                    $BuildNumber = ($regex.groups | ? { $_.Name -eq "build" }).Value
                    If (![String]::IsNullOrEmpty($BuildNumber) -and $Versions[$VersionNumber].Build -notcontains $BuildNumber) {
                        $Versions[$VersionNumber].Add([PSCustomObject][Ordered]@{
                                Build = $BuildNumber
                                Date = ([DateTime]::Parse(($regex.groups | ? { $_.Name -eq "date" }).Value)).ToString("yyyy/MM/dd")
                                KB = ($regex.groups | ? { $_.Name -eq "kb" }).Value
                                OutOfBand = $V -match "out\-of\-band"
                            }
                        )
                    }
                }
            }
        }
    }

    $Versions
}

Get-WindowsServerBuildsList