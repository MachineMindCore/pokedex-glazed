$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dex = Get-Content "$root\scripts\dex.json" -Raw -Encoding UTF8 | ConvertFrom-Json

$entries = New-Object System.Collections.ArrayList
$suspicious = New-Object System.Collections.ArrayList
foreach ($p in $dex) {
    $locs = @($p.location -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    foreach ($l in $locs) {
        if ($l -match '[{}\[\]]' -or $l -match '<|>') { [void]$suspicious.Add("$($p.id): $l") }
    }
    $types = @()
    if ($p.type1) { $types += $p.type1 }
    if ($p.type2 -and $p.type2 -ne $p.type1) { $types += $p.type2 }
    if ($types.Count -eq 0) { $types += '?' }
    [void]$entries.Add([ordered]@{
        n = [int]$p.id
        name = $p.name
        types = $types
        loc = $locs
    })
}
Write-Host "Entries: $($entries.Count)  Suspicious location strings: $($suspicious.Count)"
$suspicious | Select-Object -First 10

$json = $entries | ConvertTo-Json -Depth 5 -Compress
# keep the inline script safe
$json = $json.Replace('<','\u003c').Replace('>','\u003e').Replace('&','\u0026').Replace([string][char]0x2028,'\u2028').Replace([string][char]0x2029,'\u2029')

$tpl = [System.IO.File]::ReadAllText("$root\template.html", [System.Text.Encoding]::UTF8)
if (-not $tpl.Contains('__DEX_DATA__')) { throw 'placeholder missing' }
$html = $tpl.Replace('__DEX_DATA__', $json)
[System.IO.File]::WriteAllText("$root\index.html", $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "index.html written: $((Get-Item "$root\index.html").Length) bytes"
