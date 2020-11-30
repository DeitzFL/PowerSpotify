$RootFolder = (Get-Item $PSScriptRoot).Parent.FullName
$Config = Get-Content "$RootFolder\LocalSettings.config" | ConvertFrom-Json
Get-ChildItem "$RootFolder\Classes" | ForEach-Object `
{
    . $_.FullName
}
Get-ChildItem "$RootFolder\Functions" | ForEach-Object `
{
    . $_.FullName
}

If (!$SpotifyInterface)
{
    $SpotifyInterface = [SpotifyInterface]::new($Config.Spotify.ClientID, $Config.Spotify.ClientSecret)
}

$Tracks = Get-TraktorInfo -CollectionFile 'C:\users\Brett\Documents\Native Instruments\Traktor 3.2.0\collection.nml' #| where { $_.Name -eq 'Is It Really Love (Extended Mix)'}
$Data = @()
ForEach ($Track in $Tracks)
{
    $SpotifyResult = Find-BestSpotifyMatch -TraktorFile $Track -SpotifyInterface $SpotifyInterface
    If ($SpotifyResult -ne $null)
    {

        $Data += [PSCustomObject]`
        @{
            TraktorName     = $Track.Name
            SpotifyName     = $SpotifyResult.Name
            TraktorArtist   = $Track.Artist
            SpotifyArtist   = $SpotifyResult.Artist
            TraktorDuration = $Track.DurationInSeconds
            SpotifyDuration = $SpotifyResult.DurationInSeconds
            ID              = $SpotifyResult.ID
            Score           = $SpotifyResult.Popularity
        }
    }
    Else
    {
        $Data += [PSCustomObject]`
        @{
            TraktorName     = $Track.Name
            SpotifyName     = $null
            TraktorArtist   = $Track.Artist
            SpotifyArtist   = $null
            TraktorDuration = $Track.DurationInSeconds
            SpotifyDuration = $null
            ID              = $null
            Score           = $null
        }
    }
    sleep 1
}

$Data | Export-Csv C:\users\Brett\Desktop\music.csv