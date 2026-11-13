$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$teamsPath = Join-Path $PSScriptRoot 'teams.json'
$outDir = Join-Path $root 'equipos'
$tmpHtml = Join-Path $root '_team-card.html'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

if (-not (Test-Path $edge)) { throw "Microsoft Edge no encontrado en $edge" }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$teamsRaw = [System.IO.File]::ReadAllText($teamsPath, [System.Text.Encoding]::UTF8)
$teams = $teamsRaw | ConvertFrom-Json
$tpl = [System.IO.File]::ReadAllText((Join-Path $root 'team-card.html'), [System.Text.Encoding]::UTF8)
$html = $tpl.Replace('__TEAMS__', $teamsRaw)
[System.IO.File]::WriteAllText($tmpHtml, $html, (New-Object System.Text.UTF8Encoding($false)))

Add-Type -AssemblyName System.Drawing

for ($i = 0; $i -lt $teams.Count; $i++) {
    $shot = Join-Path $env:TEMP ("teamcard_{0}.png" -f $i)
    Remove-Item $shot -Force -ErrorAction SilentlyContinue
    $prevEA = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $edge --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size=1200,792 --screenshot=$shot --virtual-time-budget=6000 "http://localhost:8137/_team-card.html?t=$i" 2>&1 | Out-Null
    $ErrorActionPreference = $prevEA

    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $shot) {
            if ((Get-Item $shot).Length -gt 10000) { break }
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path $shot)) { throw "No se genero la captura del equipo $($i + 1)" }
    Start-Sleep -Milliseconds 400

    $img = [System.Drawing.Bitmap]::FromFile($shot)
    try {
        $w = 2400
        $h = 1400
        if ($img.Width -lt $w -or $img.Height -lt $h) {
            throw "Captura inesperada: $($img.Width)x$($img.Height)"
        }
        $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
        $crop = $img.Clone($rect, $img.PixelFormat)
        try {
            $name = "equipo-{0}.png" -f ($i + 1)
            $crop.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Host "Guardado equipos\$name ($($crop.Width)x$($crop.Height))"
        } finally { $crop.Dispose() }
    } finally { $img.Dispose() }
}

# Gallery for quick viewing (ASCII source, HTML entities for accents)
$items = for ($i = 0; $i -lt $teams.Count; $i++) {
    $n = $i + 1
    $name = [System.Net.WebUtility]::HtmlEncode($teams[$i].name)
    "<figure><img src=""equipo-$n.png"" alt=""$name""><figcaption><b>$name</b><span>$($teams[$i].members.Count) Pok&eacute;mon</span></figcaption></figure>"
}
$gallery = @"
<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Equipos &middot; Pok&eacute;dex Glazed</title>
<style>
  body{margin:0;padding:32px;background:#080a0f;color:#e8edf7;font-family:'Segoe UI',system-ui,sans-serif}
  h1{margin:0 0 6px;font-size:24px;letter-spacing:.4px;text-transform:uppercase}
  h1 span{color:#ff5a3c}
  p{margin:0 0 26px;color:#8b98b0;font-size:13px}
  .list{display:flex;flex-direction:column;gap:26px;max-width:1200px;margin:0 auto}
  figure{margin:0}
  img{display:block;width:100%;height:auto;border:1px solid #232c3d;border-radius:18px;box-shadow:0 30px 60px -30px #000}
  figcaption{display:flex;justify-content:space-between;margin-top:8px;font-size:12px;color:#8b98b0}
  figcaption b{color:#e8edf7}
</style></head><body>
<div class="list">
  <div><h1>Equipos <span>Glazed</span></h1><p>Guardados como im&aacute;genes independientes en la carpeta <b>equipos/</b>.</p></div>
  $($items -join "`r`n  ")
</div>
</body></html>
"@
[System.IO.File]::WriteAllText((Join-Path $outDir 'index.html'), $gallery, (New-Object System.Text.UTF8Encoding($false)))

Remove-Item $tmpHtml -Force -ErrorAction SilentlyContinue
Write-Host "Listo: $($teams.Count) imagenes en $outDir"
