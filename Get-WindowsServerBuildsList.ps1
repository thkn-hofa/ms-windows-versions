Function Get-WindowsServerBuildsList {
    $WindowsVersionUpdateHistoryURIs = @(
        "https://support.microsoft.com/en-us/servicing/os/windows-10/2022/09/windows-10-update-history"
        "https://support.microsoft.com/en-gb/servicing/os/windows-server/2024/10/windows-server-2025-update-history"
    )

    $Versions = [Hashtable]@{}

    Foreach ($URI in $WindowsVersionUpdateHistoryURIs) {
        $x = Invoke-WebRequest -UseBasicParsing -Uri $URI
        $NavLinks = $x.links | ? { $_.class -eq "learnRenderLeftNavLink" }

        If ($Null -ne ($NavLinks.Outerhtml | ? { $_ -match "update history" })) {
            $UpdateHistoryNavLinks = $NavLinks | ? { $_.outerHTML -match "Update history" }
        }
        Else {
            $UpdateHistoryNavLinks = $NavLinks | ? { $_.outerHTML -match "Windows Server" } | Sort -Unique href
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

                # Foreach ($V in ($Sections[$S] | % { ([Xml]($_.outerHTML)).a."#text" })) {
                Foreach ($Href in $Sections[$S]) {
                    $V =  ([Xml]($Href.outerHTML)).a."#text"

                    # $v
                    $Regex = [Regex]::Matches($V, "(?<date>^[\w\,\s]+).*(?<kb>KB\d+\b).*OS Builds? (?<build>[\d\.]+)")
                    $BuildNumber = ($regex.groups | ? { $_.Name -eq "build" }).Value
                    If (![String]::IsNullOrEmpty($BuildNumber) -and $Versions[$VersionNumber].Build -notcontains $BuildNumber) {
                        $ParsedDate = [DateTime]::new(0)
                        $DateValid = [DateTime]::TryParse(($regex.groups | ? { $_.Name -eq "date" }).Value, [ref]$ParsedDate)

                        ## If parsing wasn't valid, open the page to check meta data 'release-date'
                        If (-not $DateValid) {
                            Write-Verbose ("Date parsing failed for build {0} with raw date string '{1}'" -f $BuildNumber, ($regex.groups | ? { $_.Name -eq "date" }).Value)

                            $PageURI = [Uri]::new([uri]$URI, $Href.href).AbsoluteUri
                            
                            $PageContent = Invoke-WebRequest -usebasicparsing -Uri $PageURI
                            $PageMetaEntries = [Regex]::Matches($PageContent.Content, "<meta\s+name=['""](?<name>[^'""]+)['""]\s+content=['""](?<content>[^'""]+)['""]\s*/?>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                            $PageMetaEntriesXML = [Xml]("<root>" + ($PageMetaEntries | ForEach-Object { $_.Value }) + "</root>")
                            $ReleaseDateMeta = ($PageMetaEntriesXML.root.meta | ? { $_.name -eq "release-date" }).content
                            If (![String]::IsNullOrEmpty($ReleaseDateMeta)) {
                                $DateValid = [DateTime]::TryParse($ReleaseDateMeta, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$ParsedDate)
                            }
                        }

                        $Versions[$VersionNumber].Add([PSCustomObject][Ordered]@{
                                Build = $BuildNumber
                                Date = $ParsedDate.ToString("yyyy/MM/dd")
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

    $Versions
}

Get-WindowsServerBuildsList
