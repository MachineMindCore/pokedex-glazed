$ErrorActionPreference = 'Stop'
$cacheDir = Join-Path $PSScriptRoot 'cache'
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
$apiFile = Join-Path $cacheDir 'glazed_api.json'

if (-not (Test-Path $apiFile)) {
    $url = 'https://fanmadepokemonglazed.fandom.com/api.php?action=parse&page=Pokemon_Locations_and_Availability&prop=wikitext&format=json&formatversion=2'
    & curl.exe -sS -L -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36' -o $apiFile $url
    Write-Host "Downloaded wiki data"
}

$raw = [System.IO.File]::ReadAllText($apiFile, [System.Text.Encoding]::UTF8)
$j = $raw | ConvertFrom-Json
$wt = ($j.parse.wikitext -replace "`r`n", "`n")

$start = $wt.IndexOf('{|')
$end = $wt.IndexOf('|}', $start)
$table = $wt.Substring($start, $end - $start)

$rows = $table -split "\n\|-" | Select-Object -Skip 1
$knownTypes = @('Normal','Fire','Water','Electric','Grass','Ice','Fighting','Poison','Ground','Flying','Psychic','Bug','Rock','Ghost','Dragon','Dark','Steel','Fairy','?')

$dex = New-Object System.Collections.ArrayList

foreach ($row in $rows) {
    $lines = @($row -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' -and $_ -ne '|}' })
    $cells = New-Object System.Collections.ArrayList
    foreach ($line in $lines) {
        if (-not $line.StartsWith('|')) { continue }
        $body = $line.Substring(1)
        $colspan = $false
        $mAttr = [regex]::Match($body, '^\s*([^|]*colspan[^|]*)\|(.*)$')
        if ($mAttr.Success) { $colspan = $true; $body = $mAttr.Groups[2].Value }
        [void]$cells.Add([pscustomobject]@{ text = $body.Trim(); colspan = $colspan })
    }
    if ($cells.Count -lt 3) { continue }
    if ($cells[0].text -notmatch '^#?\s*(\d+)') { continue }
    $id = [int]$Matches[1]
    $name = ($cells[1].text -replace '\[\[|\]\]','').Trim()

    $i = 2
    $type1 = ''; $type2 = ''
    if ($i -lt $cells.Count -and $knownTypes -contains $cells[$i].text) {
        $type1 = $cells[$i].text
        $i++
        if ($cells[$i-1].colspan) {
            # single type spanning both columns
        } elseif ($i -lt $cells.Count -and $knownTypes -contains $cells[$i].text) {
            $type2 = $cells[$i].text
            $i++
        }
    } else {
        if ($i -lt $cells.Count) { $type1 = $cells[$i].text; $i++ }
    }
    if ($type2 -eq $type1) { $type2 = '' }

    $loc = if ($i -lt $cells.Count) { $cells[$i].text } else { '' }
    $loc = $loc -replace '\[\[|\]\]',''
    if ([string]::IsNullOrWhiteSpace($loc)) { $loc = '' }

    [void]$dex.Add([pscustomobject][ordered]@{
        id = $id
        name = $name
        type1 = $type1
        type2 = $type2
        location = $loc
    })
}

Write-Host "Rows: $($dex.Count)"
$ids = @($dex | ForEach-Object { $_.id })
$missing = 0..(($ids | Measure-Object -Maximum).Maximum) | Where-Object { $ids -notcontains $_ }
Write-Host "Missing ids: $($missing -join ',')"
Write-Host "Last: $($dex[-1].id) $($dex[-1].name)"

$dex | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $PSScriptRoot 'dex.json') -Encoding UTF8
