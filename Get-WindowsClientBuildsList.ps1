Function Get-WindowsServerBuildsList {
    $WindowsVersionUpdateHistoryURIs = @(
        "https://support.microsoft.com/en-us/topic/windows-11-version-22h2-update-history-ec4229c3-9c5f-4e75-9d6d-9025ab70fcce"
        "https://support.microsoft.com/en-us/topic/windows-10-and-windows-server-2019-update-history-725fc2e1-4443-6831-a5ca-51ff5cbcb059"
    )

    $Versions = [Hashtable]@{}

    Foreach ($URI in $WindowsVersionUpdateHistoryURIs) {
        $x = Invoke-WebRequest -UseBasicParsing -Uri $URI
        $NavLinks = $x.links | ? { $_.class -eq "supLeftNavLink" }

        If ($Null -ne ($NavLinks.Outerhtml | ? { $_ -match "update history" })) {
            $UpdateHistoryNavLinks = $NavLinks | ? { $_.outerHTML -match "Update history" }
        }
        Else {
            $UpdateHistoryNavLinks = $NavLinks | ? { $_.outerHTML -match "Windows(?!\s+Server)" } | Group-Object -Property href | % { $_.Group | Select -First 1 }
        }

        $SectionFirsts = $UpdateHistoryNavLinks | Sort-Object -Unique @{E={([Xml]($_.outerHTML)).a."#text"}},href | Sort-Object @{E={$NavLinks.IndexOf($_)}}
        
        $Sections = [Hashtable][Ordered]@{}
        For ($i=0 ; $i -lt @($SectionFirsts).Count ; $i++) {
            If ($SectionFirsts[$i].outerHTML -match "Windows(?!\s+Server)") {
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

            Foreach ($T in @(($Title -split "\band\b") | ? { $_ -match "Windows(?!\s+Server)" })) {
                If ($t -match "initial version released") {
                    # Skip
                    continue
                }
                ElseIf ($t -match "version") {
                    $Matches = [Regex]::Matches($T,"(?<flavour>Windows \d+).*version (?<version>[\w]+)",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                }
                Else {
                    $Matches = [Regex]::Matches($T,"Windows(?!\s+Server)+,? (?<version>[\w]+)",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                }
                $VersionNumber = "{0} {1}" -f (($Matches.Groups | ? { $_.name -eq "Flavour"}).Value | Select -Last 1),(($Matches.Groups | ? { $_.name -eq "Version"}).Value | Select -Last 1)
                Write-Verbose ("{0} - {1}" -f $T, $VersionNumber)

                If ($Versions.Keys -notcontains $VersionNumber) {
                    $Versions.Add($VersionNumber, $(New-Object System.Collections.Generic.List[PSCustomObject]))
                }

                Foreach ($V in ($Sections[$S] | % { ([Xml]($_.outerHTML)).a."#text" })) {
                    # $v
                    $Regex = [Regex]::Matches($V, "(?<date>^[\w\,\s]+).*(?<kb>KB\d+\b).*OS Builds? (?<build>[\d\.]+)")
                    If ([String]::IsNullOrEmpty($Regex)) { Continue }
                    $BuildNumber = ($regex.groups | ? { $_.Name -eq "build" }).Value
                    If (![String]::IsNullOrEmpty($BuildNumber) -and $Versions[$VersionNumber].Build -notcontains $BuildNumber) {
                        $Versions[$VersionNumber].Add([PSCustomObject][Ordered]@{
                                Build = $BuildNumber
                                Date = ([DateTime]::Parse(($regex.groups | ? { $_.Name -eq "date" }).Value)).ToString("yyyy/MM/dd")
                                KB = ($regex.groups | ? { $_.Name -eq "kb" }).Value
                                OutOfBand = $V -match "out\-of\-band"
                                Preview = $V -match "preview"
                            }
                        )
                    }
                }
            }
        }
    }

    $Versions.GetEnumerator() | Sort-Object -Property Name
}

Get-WindowsServerBuildsList