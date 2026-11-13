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
$left = 56
$top = 42
$footerH = 62
$canvasW = $left + $mapW
$canvasH = $top + $mapH + $footerH

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
    return [pscustomobject]@{ name = $(if ($c -le 16) { 'Mar de Tunod' } else { 'Mar de Johto' }) }
  }
  $exact = $zones | Where-Object { $_.c -eq $c -and $_.r -eq $r } | Select-Object -First 1
  if ($exact) { return [pscustomobject]@{ name = $exact.name } }
  $best = $zones[0]
  $bestD = [double]::MaxValue
  foreach ($z in $zones) {
    $d = [Math]::Pow($z.c - $c, 2) + [Math]::Pow($z.r - $r, 2)
    if ($d -lt $bestD) { $bestD = $d; $best = $z }
  }
  return [pscustomobject]@{ name = $best.name }
}

# ---------- reference image ----------
$src = [System.Drawing.Bitmap]::FromFile($mapPath)
$bmp = New-Object System.Drawing.Bitmap $canvasW, $canvasH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.Clear([System.Drawing.Color]::FromArgb(11, 14, 20))

# header bars
$barBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(15, 20, 29))
$g.FillRectangle($barBrush, 0, 0, $left, $top + $mapH)
$g.FillRectangle($barBrush, $left, 0, $mapW, $top)

$g.DrawImage($src, $left, $top, $mapW, $mapH)

$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(20, 255, 255, 255))
$black = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(34, 0, 0, 0))
for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $brush = if ((($r + $c) % 2) -eq 0) { $white } else { $black }
        $g.FillRectangle($brush, $left + $c * $cell, $top + $r * $cell, $cell, $cell)
    }
}

$penDark = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(120, 8, 10, 14)), 1
$penLight = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(35, 255, 255, 255)), 1
for ($c = 0; $c -le $cols; $c++) {
    $x = $left + $c * $cell
    $g.DrawLine($penDark, $x, $top, $x, $top + $mapH)
    if ($c -lt $cols) { $g.DrawLine($penLight, $x + 1, $top, $x + 1, $top + $mapH) }
}
for ($r = 0; $r -le $rows; $r++) {
    $y = $top + $r * $cell
    $g.DrawLine($penDark, $left, $y, $left + $mapW, $y)
    if ($r -lt $rows) { $g.DrawLine($penLight, $left, $y + 1, $left + $mapW, $y + 1) }
}

# axis labels
$axisFont = New-Object System.Drawing.Font 'Segoe UI', 17, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$axisBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(232, 237, 247))
$axisMuted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(139, 152, 176))
$center = New-Object System.Drawing.StringFormat
$center.Alignment = [System.Drawing.StringAlignment]::Center
$center.LineAlignment = [System.Drawing.StringAlignment]::Center

for ($c = 0; $c -lt $cols; $c++) {
    $rect = New-Object System.Drawing.RectangleF ($left + $c * $cell), 0, $cell, $top
    $g.DrawString(($c + 1).ToString(), $axisFont, $axisBrush, $rect, $center)
}
for ($r = 0; $r -lt $rows; $r++) {
    $rect = New-Object System.Drawing.RectangleF 0, ($top + $r * $cell), $left, $cell
    $letter = [string][char](65 + $r)
    $g.DrawString($letter, $axisFont, $axisBrush, $rect, $center)
}

$borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 51, 64, 90)), 2
$g.DrawLine($borderPen, $left, $top, $left, $top + $mapH)
$g.DrawLine($borderPen, $left, $top, $left + $mapW, $top)

# coordinate labels inside every cell
$cellFont = New-Object System.Drawing.Font 'Consolas', 9.5, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$cellOutline = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(210, 0, 0, 0))
$cellText = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
$near = New-Object System.Drawing.StringFormat
$near.Alignment = [System.Drawing.StringAlignment]::Near
$near.LineAlignment = [System.Drawing.StringAlignment]::Near
for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $label = ([string][char](65 + $r)) + ($c + 1).ToString()
        $x = $left + $c * $cell + 4
        $y = $top + $r * $cell + 3
        foreach ($ox in -1, 0, 1) {
            foreach ($oy in -1, 0, 1) {
                if ($ox -eq 0 -and $oy -eq 0) { continue }
                $g.DrawString($label, $cellFont, $cellOutline, ($x + $ox), ($y + $oy), $near)
            }
        }
        $g.DrawString($label, $cellFont, $cellText, $x, $y, $near)
    }
}

# footer
$footerY = $top + $mapH
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(15, 20, 29))), 0, $footerY, $canvasW, $footerH)
$g.DrawLine((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(51, 64, 90)), 1), 0, $footerY, $canvasW, $footerY)
$fontTitle = New-Object System.Drawing.Font 'Segoe UI', 17, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$fontSub = New-Object System.Drawing.Font 'Segoe UI', 12, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(232, 237, 247))
$mutedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(139, 152, 176))
$g.DrawString('CUADRICULA DE REFERENCIA  -  30 x 20', $fontTitle, $whiteBrush, 20, $footerY + 9)
$g.DrawString('Filas = letras (A-T)  -  Columnas = numeros (1-30)  -  1 casilla = 8 x 8 px del mapa original  -  edita mapa/localizaciones.csv', $fontSub, $mutedBrush, 20, $footerY + 34)

$bmp.Save($outImage, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $src.Dispose()

# ---------- CSV ----------
$csvRows = New-Object System.Collections.ArrayList
for ($r = 0; $r -lt $rows; $r++) {
    $letter = [string][char](65 + $r)
    for ($c = 0; $c -lt $cols; $c++) {
        $z = Get-Zone $c $r
        [void]$csvRows.Add([pscustomobject]@{
            fila = $letter
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
- cuadricula.png: mapa 30x20 con patron de ajedrez. Las filas son letras (A-T) y las columnas numeros (1-30).
- localizaciones.csv: una fila por casilla (600 filas).

Columnas del CSV:
- fila: letra de la fila, de A a T
- columna: numero de columna, de 1 a 30
- zona_actual: lo que muestra ahora la app en esa casilla
- zona_correcta: escribe aqui el nombre real de la zona. Dejalo vacio si ya es correcto.
- notas: opcional

Ejemplo:
fila,columna,zona_actual,zona_correcta,notas
I,10,Glenwood Town,Glenwood Town,

Cuando termines, avisame y regenero los datos del mapa usando la columna zona_correcta.
"@
[System.IO.File]::WriteAllText($outReadme, $readme, (New-Object System.Text.UTF8Encoding($true)))

Write-Host "Imagen: $outImage"
Write-Host "CSV:    $outCsv ($($csvRows.Count) filas)"
Write-Host "LEEME:  $outReadme"
