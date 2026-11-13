$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $PSScriptRoot 'cache'
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$cssFile = Join-Path $cache 'pokemon.css'
$sheetFile = Join-Path $cache 'pokemon-large.png'
$baseUrl = 'https://thatswhatyouget.github.io/tpp-progress/'

if (-not (Test-Path $cssFile)) {
    & curl.exe -sS -L -A 'Mozilla/5.0' -o $cssFile 'https://thatswhatyouget.github.io/tpp-progress/css/pokemon.css'
    Write-Host 'Downloaded sprite CSS'
}
if (-not (Test-Path $sheetFile)) {
    & curl.exe -sS -L -A 'Mozilla/5.0' -o $sheetFile 'https://thatswhatyouget.github.io/tpp-progress/img/pokemon-large.png'
    Write-Host 'Downloaded sprite sheet'
}

$css = [System.IO.File]::ReadAllText($cssFile, [System.Text.Encoding]::UTF8)

$posMap = @{}
$extMap = @{}
foreach ($rule in ($css -split '\}')) {
    $m = [regex]::Match($rule, '^\s*\.pokesprite\.([a-z0-9\-]+)\s+img\s*\{([^{}]*)$', 'Singleline')
    if (-not $m.Success) { continue }
    $cls = $m.Groups[1].Value
    $decl = $m.Groups[2].Value
    $mp = [regex]::Match($decl, 'background-position:\s*-?(\d+)em\s+-?(\d+)em')
    if ($mp.Success -and -not $posMap.ContainsKey($cls)) {
        $posMap[$cls] = @{ col = [int]$mp.Groups[1].Value; row = [int]$mp.Groups[2].Value }
    }
    $me = [regex]::Match($decl, 'background-image:\s*url\("([^"]+)"\)')
    if ($me.Success -and -not $extMap.ContainsKey($cls)) {
        $extMap[$cls] = $me.Groups[1].Value
    }
}

$female = [string][char]0x2640
$male = [string][char]0x2642
$aliases = @{
  'MissingNo' = 'missingno'
  ('Nidoran' + $female) = 'nidoranf'
  ('Nidoran' + $male) = 'nidoranm'
  'Scarfed Pikachu' = 'pikachu-b'
  'Enraged Mew' = 'mew-b'
  'Kyurem-B' = 'kyurem-b'
  'Kyurem-W' = 'kyurem-w'
  'Mega Venusaur' = 'm-venusaur'
  'Mega Charizard X' = 'm-charizardx'
  'Mega Charizard Y' = 'm-charizardy'
  'Mega Blastoise' = 'm-blastoise'
  'Mega Lucario' = 'm-lucario'
  'Mega Salamence' = 'm-salamence'
  'Mega Absol' = 'm-absol'
  'Mega Manectric' = 'm-manectric'
  'Deoxys (Attack Forme)' = 'deoxys-attack'
  'Frosslass' = 'froslass'
}
function Normalize([string]$name) {
    if ($aliases.ContainsKey($name)) { return $aliases[$name] }
    $s = $name.ToLowerInvariant()
    $s = $s.Replace($female, 'f').Replace($male, 'm')
    $s = $s -replace "[\.':]", ''
    $s = $s -replace '\s+', '-'
    return $s
}

$dex = Get-Content "$root\scripts\dex.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$outDir = "$root\sprites"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Add-Type -AssemblyName System.Drawing
$sheet = [System.Drawing.Bitmap]::FromFile($sheetFile)
$done = 0; $downloaded = 0; $errors = New-Object System.Collections.ArrayList

foreach ($p in $dex) {
    $cls = Normalize $p.name
    $file = Join-Path $outDir ('{0:000}.png' -f $p.id)
    $src = $null
    if ($cls -eq 'deoxys-attack') {
        $src = $baseUrl + 'img/alternate/deoxys-attack.png'
    } elseif ($extMap.ContainsKey($cls)) {
        $src = $baseUrl + ($extMap[$cls] -replace '^\.\./', '')
    }
    if ($src) {
        $tmp = "$env:TEMP\spr_$($p.id).png"
        & curl.exe -sS -L -A "Mozilla/5.0" -o $tmp $src
        if ((Test-Path $tmp) -and (Get-Item $tmp).Length -gt 0) {
            Copy-Item $tmp $file -Force
            $downloaded++
        } else {
            [void]$errors.Add("$($p.id) $($p.name) $src")
        }
    } elseif ($posMap.ContainsKey($cls)) {
        $c = $posMap[$cls]
        $rect = New-Object System.Drawing.Rectangle ($c.col*64), ($c.row*64), 64, 64
        $bmp = $sheet.Clone($rect, $sheet.PixelFormat)
        $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $done++
    } else {
        [void]$errors.Add("$($p.id) $($p.name) NO SPRITE ($cls)")
    }
}
$sheet.Dispose()
Write-Host "Cropped from sheet: $done  Downloaded: $downloaded  Errors: $($errors.Count)"
$errors | Select-Object -First 20

# Verify dimensions / transparency
$bad = @()
Get-ChildItem $outDir -Filter *.png | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    if ($img.Width -ne 64 -or $img.Height -ne 64) { $bad += "$($_.Name) $($img.Width)x$($img.Height)" }
    $img.Dispose()
}
Write-Host "Non-64x64: $($bad.Count)"
$bad | Select-Object -First 20
Write-Host "Total files: $((Get-ChildItem $outDir -Filter *.png).Count)"
