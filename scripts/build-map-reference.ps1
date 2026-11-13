$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mapPath = Join-Path $root 'mapa\world-map.png'
$outImage = Join-Path $root 'mapa\cuadricula.png'
$outCsv = Join-Path $root 'mapa\localizaciones.csv'
$outReadme = Join-Path $root 'mapa\LEEME.txt'

Add-Type -AssemblyName System.Drawing

$cols = 30
$rows = 20
$cell = 64
$mapW = $cols * $cell
$mapH = $rows * $cell

$zones = @(
  @{ name='Haunted Isle'; c=7; r=3 },
  @{ name='Northcoast Town'; c=10; r=3 },
  @{ name='Seaspray Town'; c=3; r=7 },
  @{ name='Mt. Stratus'; c=9; r=6 },
  @{ name='Chocco Town'; c=11; r=6 },
  @{ name='Geminite Village'; c=5; r=9 },
  @{ name='Glenwood Town'; c=9; r=8 },
  @{ name='Palmtree Resort'; c=11; r=8 },
  @{ name='Cape Azure'; c=2; r=11 },
  @{ name='Southerly City'; c=5; r=11 },
  @{ name='Serenity Isle'; c=17; r=11 },
  @{ name='Darkwood Town'; c=8; r=12 },
  @{ name='Tunod League'; c=11; r=12 },
  @{ name='Oceanview City'; c=15; r=12 },
  @{ name='Stormy City'; c=4; r=14 },
  @{ name='Cianwood City'; c=18; r=4 },
  @{ name='Ecruteak City'; c=22; r=7 },
  @{ name='Bell Tower'; c=24; r=7 },
  @{ name='Mahogany Town'; c=27; r=7 },
  @{ name='Azalea Town'; c=19; r=9 },
  @{ name='Violet City'; c=23; r=9 },
  @{ name='Olivine City'; c=21; r=11 },
  @{ name='Goldenrod City'; c=22; r=13 },
  @{ name='Cherrygrove City'; c=25; r=12 },
  @{ name='Blackthorn City'; c=28; r=12 },
  @{ name='New Bark Town'; c=28; r=15 }
)

$water = @(
  '111000000000000',
  '111000000000000',
  '110010000000000',
  '100000000000000',
  '100000011000000',
  '000000100000000',
  '001000100100000',
  '000111111101100',
  '111111111111111',
  '111111111111111'
)

function Is-Water($c, $r) {
  $row = $water[[int][Math]::Floor($r / 2)]
  return (-not $row) -or ($row[[int][Math]::Floor($c / 2)] -eq '1')
}

function Get-Zone($c, $r) {
  if (Is-Water $c $r) {
    return [pscustomobject]@{ name = $(if ($c -le 16) { 'Mar de Tunod' } else { 'Mar de Johto' }); region = $(if ($c -le 16) { 'Tunod' } else { 'Johto' }) }
  }
  $exact = $zones | Where-Object { $_.c -eq $c -and $_.r -eq $r } | Select-Object -First 1
  if ($exact) { return [pscustomobject]@{ name = $exact.name; region = 'Tunod' } }
  $best = $zones[0]
  $bestD = [double]::MaxValue
  foreach ($z in $zones) {
    $d = [Math]::Pow($z.c - $c, 2) + [Math]::Pow($z.r - $r, 2)
    if ($d -lt $bestD) { $bestD = $d; $best = $z }
  }
  return [pscustomobject]@{ name = $best.name; region = 'Tunod' }
}

# ---------- reference image ----------
$src = [System.Drawing.Bitmap]::FromFile($mapPath)
$bmp = New-Object System.Drawing.Bitmap $mapW, ($mapH + 62)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.Clear([System.Drawing.Color]::FromArgb(11, 14, 20))
$g.DrawImage($src, 0, 0, $mapW, $mapH)

$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(20, 255, 255, 255))
$black = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(34, 0, 0, 0))
for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $brush = if ((($r + $c) % 2) -eq 0) { $white } else { $black }
        $g.FillRectangle($brush, $c * $cell, $r * $cell, $cell, $cell)
    }
}

$penDark = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(120, 8, 10, 14)), 1
$penLight = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(35, 255, 255, 255)), 1
for ($c = 0; $c -le $cols; $c++) {
    $x = $c * $cell
    $g.DrawLine($penDark, $x, 0, $x, $mapH)
    if ($c -lt $cols) { $g.DrawLine($penLight, $x + 1, 0, $x + 1, $mapH) }
}
for ($r = 0; $r -le $rows; $r++) {
    $y = $r * $cell
    $g.DrawLine($penDark, 0, $y, $mapW, $y)
    if ($r -lt $rows) { $g.DrawLine($penLight, 0, $y + 1, $mapW, $y + 1) }
}

$font = New-Object System.Drawing.Font 'Consolas', 9.5, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$outline = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(210, 0, 0, 0))
$label = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = [System.Drawing.StringAlignment]::Near
$fmt.LineAlignment = [System.Drawing.StringAlignment]::Near
for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $text = 'F' + ($r + 1) + ' C' + ($c + 1)
        $x = $c * $cell + 4
        $y = $r * $cell + 3
        foreach ($ox in -1, 0, 1) {
            foreach ($oy in -1, 0, 1) {
                if ($ox -eq 0 -and $oy -eq 0) { continue }
                $g.DrawString($text, $font, $outline, ($x + $ox), ($y + $oy), $fmt)
            }
        }
        $g.DrawString($text, $font, $label, $x, $y, $fmt)
    }
}

$footerY = $mapH
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(15, 20, 29))), 0, $footerY, $mapW, 62)
$g.DrawLine((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(51, 64, 90)), 1), 0, $footerY, $mapW, $footerY)
$fontTitle = New-Object System.Drawing.Font 'Segoe UI', 17, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$fontSub = New-Object System.Drawing.Font 'Segoe UI', 12, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(232, 237, 247))
$mutedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(139, 152, 176))
$g.DrawString('CUADRICULA DE REFERENCIA  -  30 x 20', $fontTitle, $whiteBrush, 24, $footerY + 10)
$g.DrawString('F = fila  -  C = columna  -  1 casilla = 8 x 8 px del mapa original  -  edita mapa/localizaciones.csv', $fontSub, $mutedBrush, 24, $footerY + 34)

$bmp.Save($outImage, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $src.Dispose()

# ---------- CSV ----------
$csvRows = New-Object System.Collections.ArrayList
for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $z = Get-Zone $c $r
        [void]$csvRows.Add([pscustomobject]@{
            fila = $r + 1
            columna = $c + 1
            zona_actual = $z.name
            zona_correcta = ''
            notas = ''
        })
    }
}
$csvRows | Export-Csv -Path $outCsv -NoTypeInformation -Encoding UTF8

# ---------- readme ----------
$readme = @"
MAPA - CUADRICULA DE REFERENCIA

Archivos:
- cuadricula.png: mapa 30x20 con patron de ajedrez y etiquetas F(fila) C(columna).
- localizaciones.csv: una fila por casilla (600 filas).

Columnas del CSV:
- fila: 1..20 (coincide con la F de la imagen)
- columna: 1..30 (coincide con la C de la imagen)
- zona_actual: lo que muestra ahora la app en esa casilla
- zona_correcta: escribe aqui el nombre real de la zona. Dejalo vacio si ya es correcto.
- notas: opcional

Ejemplo:
fila,columna,zona_actual,zona_correcta,notas
10,10,Glenwood Town,Glenwood Town,

Cuando termines, avisame y regenero los datos del mapa usando la columna zona_correcta.
"@
[System.IO.File]::WriteAllText($outReadme, $readme, (New-Object System.Text.UTF8Encoding($true)))

Write-Host "Imagen: $outImage"
Write-Host "CSV:    $outCsv ($($csvRows.Count) filas)"
Write-Host "LEEME:  $outReadme"
