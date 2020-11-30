Function Get-TraktorInfo
{
    Param
    (
        $CollectionFile
    )

    [xml]$TraktorCollection = Get-Content $CollectionFile
    ForEach ($Track in $TraktorCollection.NML.Collection.Entry)
    {

        If ($Track.Info.Release_Date -ne $null)
        {
            [DateTime]$ReleaseDate = $Track.Info.Release_Date
        }
        $Path = "$(($Track.Location.DIR).Replace(':',''))$($Track.LOCATION.FILE)"
        [PSCustomObject]`
        @{
            Name              = $Track.Title
            Artist            = $Track.Artist
            Album             = $Track.Album.Title
            BPM               = [Math]::Round($Track.TEMPO.BPM, 0)
            DurationInSeconds = [Int32]$Track.Info.PlayTime
            ReleaseDate       = $ReleaseDate
            Path              = $Path
        }
    }
}
