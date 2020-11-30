Class SpotifyToken
{
    # Properties
    [String]$ClientID
    [String]$AccessToken
    [DateTime]$ValidFrom
    [DateTime]$ValidTo

    # Hidden Properties
    Hidden [String]$BearerToken
    Hidden [String]$ClientSecret

    # Constructor
    SpotifyToken($ClientID, $ClientSecret)
    {
        $This.ClientID = $ClientID
        $This.ClientSecret = $ClientSecret
        $StringToEncode = "$($This.ClientID):$($This.ClientSecret)"
        $This.BearerToken = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($StringToEncode))
    }

    # Get a token if needed
    [String]GetTokenAsync()
    {
        If ((!$This.AccessToken) -or ($This.ValidTo -le [datetime]::Now))
        {
            $RestParams = `
            @{
                URI     = 'https://accounts.spotify.com/api/token'
                Method  = 'POST'
                Headers = `
                @{
                    'Authorization' = 'Basic ' + $This.BearerToken
                    'Content-Type'  = 'application / x-www-form-urlencoded'
                }
                Body    =
                @{
                    grant_type = 'client_credentials'
                }
            }
            Try
            {
                $TokenRequest = Invoke-RestMethod @RestParams -ContentType 'application/x-www-form-urlencoded'
                $This.AccessToken = $TokenRequest.access_token
                $This.ValidFrom = [DateTime]::Now
                $This.ValidTo = $This.ValidFrom.AddSeconds($TokenRequest.expires_in)
            }
            Catch
            {
                Throw "Error generating token $($_.ToString())"
            }
        }
        Return $This.AccessToken
    }
}

Class SpotifyInterface : SpotifyToken
{
    Static $RootEndpoint = 'https://api.spotify.com/v1'

    SpotifyInterface($ClientID, $ClientSecret) : base ($ClientID, $ClientSecret)
    {
    }

    Static [PSCustomObject]InvokeAdHocSpotifyRequest($Endpoint, $AccessToken)
    {
        $RestParams =
        @{
            URI     = [SpotifyInterface]::RootEndpoint + $Endpoint
            Method  = 'GET'
            Headers =
            @{
                authorization = "Bearer " + $AccessToken
            }
        }
        Try
        {
            Return Invoke-RestMethod @RestParams -ErrorAction Stop
        }
        Catch
        {
            Return [PSCustomObject]`
            @{
                Error      = $True
                StatusCode = [Int32]$_.Exception.Response.statuscode
                Message    = $_.Exception.Message
                Endpoint   = $RestParams.Endpoint
            }
        }
    }

    [PSCustomObject]InvokeSpotifyRequest($Endpoint)
    {
        $RestParams =
        @{
            URI     = [SpotifyInterface]::RootEndpoint + $Endpoint
            Method  = 'GET'
            Headers =
            @{
                authorization = "Bearer " + $This.GetTokenAsync()
            }
        }
        Try
        {
            Return Invoke-RestMethod @RestParams -ErrorAction Stop
        }
        Catch
        {
            Return [PSCustomObject]`
            @{
                Error      = $True
                StatusCode = [Int32]$_.Exception.Response.statuscode
                Message    = $_.Exception.Message
                Endpoint   = $RestParams.Endpoint
            }
        }
    }


    [Array]FindTrack ($TrackName, $TrackArtist, $Limit)
    {
        $Results = [System.Collections.ArrayList]::new()
        If ($TrackName -like "*(*")
        {
            $TrackName = ($TrackName.Split('(')[0]).TrimEnd()
        }
        $TrackName = $TrackName.Replace("(", "")
        $TrackName = $TrackName.Replace(")", "")
        $TrackName = $TrackName.Replace(" ", '%20')
        $TrackName = $TrackName.Replace("'", "")
        $TrackArtist = $TrackArtist.Replace(" ", '%20')
        $TrackArtist = $TrackArtist.Replace("'", "")
        $TrackArtist = $TrackArtist.Replace(",", "%2C")
        $Endpoint = '/search'
        $Query = "?q=track%3A$TrackName%20artist%3A$TrackArtist&type=track&limit=$Limit"
        $SearchRequest = $This.InvokeSpotifyRequest($Endpoint + $Query)
        Write-Verbose "$($SearchRequest.tracks.total) found. Returning $($SearchRequest.tracks.limit)"
        $SearchRequest.tracks.items | % { $Results.Add([SpotifyTrack]::new($_)) }
        Return $Results
    }

    [SpotifyItem]GetSpotifyItem([String]$SpotifyID, [String]$Type)
    {
        $ClassType = $null
        Switch ($Type)
        {
            'Track'
            {
                $ClassType = 'SpotifyTrack'
            }
        }
        Return (New-Object -TypeName $ClassType -ArgumentList $SpotifyID, $This.GetTokenAsync())
    }

}

Class SpotifyItem
{
    [String]$Type
    [String]$ID
    [String]$Endpoint
    Hidden [PSCustomObject]$RawData

    SpotifyItem ([PSCustomObject]$RawData, [String]$Type)
    {
        $This.Type = $Type
        $This.ID = $RawData.id
        $This.Endpoint = 'https://api.spotify.com/v1/' + $Type + '/' + $RawData.id
        $This.RawData = $RawData
    }

    SpotifyItem ([String]$ID, [String]$Type, $SpotifyAccessToken)
    {
        $This.Type = $Type
        $This.ID = $ID
        $This.Endpoint = 'https://api.spotify.com/v1/' + $Type + '/' + $ID
        Try
        {
            $This.RawData = $This.GetItemByID($This.Endpoint, $SpotifyAccessToken)
            If ($This.RawData.Error)
            {
                Throw 'Error while running GET ITEM BY ID'
            }
        }
        Catch
        {
            Throw
        }
    }


    [PSCustomObject]GetItemByID($Endpoint, $SpotifyAccessToken)
    {
        $RestParams =
        @{
            URI     = $Endpoint
            Method  = 'GET'
            Headers =
            @{
                authorization = "Bearer " + $SpotifyAccessToken
            }
        }
        Try
        {
            Return Invoke-RestMethod @RestParams -ErrorAction Stop
        }
        Catch
        {
            Return [PSCustomObject]`
            @{
                Error      = $True
                StatusCode = [Int32]$_.Exception.Response.statuscode
                Message    = $_.Exception.Message
                Endpoint   = $RestParams.Endpoint
            }
        }
    }
}

Class SpotifyTrack : SpotifyItem
{
    [String]$Name
    [String]$Artist
    [String]$Album
    [Int32]$DurationInSeconds
    [DateTime]$ReleaseDate
    [Int32]$Popularity

     Hidden [SpotifyTrackAudioDetails]$AudioDetails

    SpotifyTrack ($RawData) : Base ($RawData, 'tracks')
    {
        $This.Name = $This.RawData.Name
        $This.Artist = $This.RawData.artists.name -join ', '
        $This.Album = $This.RawData.album.name

        If ($This.RawData.album.release_date.length -lt 5)
        {
            $This.ReleaseDate = "1/1/$($This.RawData.album.release_date)"
        }
        Else { $This.ReleaseDate = $This.RawData.album.release_date}
        $This.DurationInSeconds = $This.RawData.duration_ms / 1000
        $This.Popularity = $This.RawData.Popularity
    }

    SpotifyTrack ($SpotifyID, $SpotifyAccessToken) : Base ($SpotifyID, 'tracks',$SpotifyAccessToken)
    {
        $This.Name = $This.RawData.Name
        $This.Artist = $This.RawData.artists.name -join ', '
        $This.Album = $This.RawData.album.name
        $This.ReleaseDate = $This.RawData.album.release_date
        $This.DurationInSeconds = $This.RawData.duration_ms / 1000
        $This.Popularity = $This.RawData.Popularity
        $This.AudioDetails = [SpotifyTrackAudioDetails]::New($This.ID, $SpotifyAccessToken)
    }

    [String]FormatDuration()
    {

        $Now = [DateTime]::Now
        $TrackLength = New-TimeSpan -Start $Now -End ($Now.AddMilliseconds($This.RawData.duration_ms))
        If ($TrackLength.Seconds -lt 10)
        {
            Return "$($TrackLength.Minutes):0$($TrackLength.Seconds)"
        }
        Else
        {
            Return "$($TrackLength.Minutes):$($TrackLength.Seconds)"
        }
    }

    GetAudioDetails($SpotifyAccessToken)
    {
        $This.AudioDetails = [SpotifyTrackAudioDetails]::New($This.ID, $SpotifyAccessToken)
    }

}

Class SpotifyTrackAudioDetails
{
    [Decimal]$Danceability
    [Decimal]$Energy
    [Int32]$Key
    [Int32]$Mode
    [Decimal]$Speechiness
    [Decimal]$Valence
    [Decimal]$BPM
    [Int32]$TimeSignature

    Hidden $RawData

    SpotifyTrackAudioDetails($SpotifyID, $SpotifyAccessToken)
    {
        $This.RawData = [SpotifyInterface]::InvokeAdHocSpotifyRequest('/audio-features/' + $SpotifyID, $SpotifyAccessToken )
        $This.Danceability = $This.RawData.Danceability
        $This.Energy = $This.RawData.Energy
        $This.Key = $This.RawData.Key
        $This.Mode = $This.RawData.Mode
        $This.Speechiness = $This.RawData.Speechiness
        $This.Valence = $This.RawData.Valence
        $This.BPM = [Math]::Round($This.RawData.Tempo, 0)
        $This.TimeSignature = $This.RawData.time_signature
    }
}

Class SpotifyPlaylist : SpotifyItem
{
    [String]$Name
    [Int32]$Followers
    [Array]$Tracks

    SpotifyPlaylist ($SpotifyID, $SpotifyAccessToken) : Base ($SpotifyID, 'playlists',$SpotifyAccessToken)
    {
        $This.Name = $This.RawData.Name
        $This.Followers = $This.RawData.Followers.Total
        $This.GetPlaylistTracks()
    }

    GetPlaylistTracks()
    {
        $This.RawData.Tracks.Items.Track | % `
        {
            $This.Tracks += [SpotifyTrack]::New($_)
        }
    }
}