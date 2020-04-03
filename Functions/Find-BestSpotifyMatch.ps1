Function Find-BestSpotifyMatch
{
    [CmdletBinding()]
    Param
    (
        $TraktorFile,
        $SpotifyInterface
    )


    [Int32]$NameWeight = 200
    [Int32]$ArtistWeight = 200
    [Int32]$DurationWeight = 200
    [Int32]$AlbumWeight = 100

    $SearchResults = $SpotifyInterface.FindTrack($TraktorFile.Name, $TraktorFile.Artist, 10)
    $ScoredResults = @()
    # If no results are found skip
    If ($SearchResults.Count -eq 0)
    {
        Write-Warning "No Spotify results found for $($TraktorFile.Name -$TraktorFile.Artist)"
        Return
    }

    ForEach ($Result in $SearchResults)
    {
        $Score = 0
        $ExactMatches = 0
        # Track Name Match
        Try
        {
            If ($Result.Name -eq $TraktorFile.Name)
            {
                $Score = $Score + $NameWeight
                $ExactMatches ++
                Write-Verbose "Spotify Result Name `'$($Result.Name)`' is an exact match on Traktor file Name `'$($TraktorFile.Name)`' adding $NameWeight. Total score is $Score"
            }
            ElseIf ($Result.Name -like "*$($TraktorFile.Name)*")
            {
                $Score = $Score + $NameWeight / 2
                Write-Verbose "Spotify Result Name `'$($Result.Name)`' is like Traktor file Name `'$($TraktorFile.Name)`' adding $($NameWeight /2). Total score is $Score"

            }

        }
        Catch
        {
            Write-Warning "Error during name matching"
        }

        # Artist Name Match
        Try
        {
            If ($Result.Artist -eq $TraktorFile.Artist)
            {
                $Score = $Score + $ArtistWeight
                $ExactMatches ++
                Write-Verbose "Spotify Result Artist `'$($Result.Artist)`' is an exact match on Traktor file Artist `'$($TraktorFile.Artist)`' adding $($ArtistWeight). Total score is $Score"
            }
            Else
            {
                $Artists = $TraktorFile.Artist -split ', '
                $Result.Artist -split ', ' | % `
                {
                    If ($Artists -contains $_)
                    {
                        $Score = $Score + [Math]::Round($ArtistWeight / $Artists.Count, 0)
                        Write-Verbose "Spotify Result Artist `'$($_)`' is an exact match for an artist on the Tracktor File `'$($TraktorFile.Name)`' adding $([Math]::Round($ArtistWeight / $Artists.Count, 0)). Total score is $Score"

                    }
                    ElseIf ($_ -like "*$($TraktorFile.Artist)*")
                    {
                        $Score = $Score + [Math]::Round(($ArtistWeight / $Artists.Count) / 2)
                        Write-Verbose "Spotify Result Artist `'$($_)`' is like an artist on the Tracktor File `'$($TraktorFile.Name)`' adding $([Math]::Round(($ArtistWeight / $Artists.Count) / 2)). Total score is $Score"
                    }
                }
            }
        }
        Catch
        {
            Write-Warning "Error during artist matching"
        }

        # Duration Match
        Try
        {
            If ($Result.DurationInSeconds -eq $TraktorFile.DurationInSeconds)
            {
                $Score = $Score + $DurationWeight
                $ExactMatches ++
                Write-Verbose "Spotify Result Duration for `'$($Result.Name)`' is an exact match on Traktor file `'$($TraktorFile.Name)`' adding $DurationWeight. Total score is $Score"
            }
            Else
            {
                $DurationRange = ($TraktorFile.DurationInSeconds - 10)..($TraktorFile.DurationInSeconds + 10)
                If ($DurationRange -contains $Result.DurationInSeconds)
                {
                    $Score = $Score + $DurationWeight / 2
                    Write-Verbose "Spotify Result Duration for `'$($Result.Name)`' is within +/- 10 seconds of Traktor file `'$($TraktorFile.Name)`' adding $($DurationWeight /2). Total score is $Score"
                }
                Else
                {
                    $Score = $Score - $DurationWeight
                    Write-Verbose "Spotify Result Duration for `'$($Result.Name)`' is NOT within +/- 10 seconds of Traktor file `'$($TraktorFile.Name)`' subtracting $($DurationWeight). Total score is $Score"
                }
            }
        }
        Catch
        {
            Write-Warning "Error during duration matching"
        }

        # Album Name Match
        Try
        {
            If ($Result.Album -eq $TraktorFile.Album)
            {
                $Score = $Score + $AlbumWeight
                Write-Verbose "Spotify Result Album `'$($Result.Name)`' is an exact match on Traktor file Album `'$($TraktorFile.Album)`' adding $AlbumWeight. Total score is $Score"
            }
            ElseIf ($Result.Album -like "*$($TraktorFile.Album)*")
            {
                $Score = $Score + $AlbumWeight / 2
                Write-Verbose "Spotify Result Album `'$($Result.Album)`' is like Traktor file Album `'$($TraktorFile.Album)`' adding $($AlbumWeight /2). Total score is $Score"
            }
            ElseIf ($Result.Album -like "*$($TraktorFile.Name)*")
            {
                $Score = $Score + $AlbumWeight / 4
                Write-Verbose "Spotify Result Album `'$($Result.Album)`' is like Traktor file Name `'$($TraktorFile.Name)`' adding $($AlbumWeight /4). Total score is $Score"
            }
        }
        Catch
        {
            Write-Warning "Error during album matching"
        }
        $Result.Popularity = $Score
        $ScoredResults += $Result
    }
    $ScoredResults | sort Popularity -Descending | select -First 1

}