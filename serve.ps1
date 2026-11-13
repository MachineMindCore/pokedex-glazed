param(
    [int]$Port = 8137,
    [string]$Bind = '127.0.0.1',
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$rootFull = [System.IO.Path]::GetFullPath($Root)

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.webp' = 'image/webp'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
    '.txt'  = 'text/plain; charset=utf-8'
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse($Bind), $Port)
try { $listener.Start() } catch {
    Write-Host "No se pudo abrir el puerto $Port. Prueba con otro: .\serve.ps1 -Port 8138" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Pokedex Glazed" -ForegroundColor Red
Write-Host "  ----------------------------------------"
Write-Host "  Sirviendo: $rootFull"
Write-Host "  Abre:      http://localhost:$Port/" -ForegroundColor Cyan
Write-Host "  Ctrl+C para detener."
Write-Host ""

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $client.ReceiveTimeout = 5000
        $client.SendTimeout = 15000
        $stream = $client.GetStream()
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($requestLine)) { $client.Close(); continue }

        # drain headers
        while ($true) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrEmpty($line)) { break }
        }

        $parts = $requestLine -split ' '
        $method = $parts[0]
        $target = if ($parts.Count -ge 2) { $parts[1] } else { '/' }
        $target = $target.Split('?')[0]
        $target = [System.Uri]::UnescapeDataString($target)
        if ($target -eq '/' -or $target -eq '') { $target = '/index.html' }

        $rel = $target.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $full = [System.IO.Path]::GetFullPath((Join-Path $rootFull $rel))

        $status = '200 OK'
        $body = $null
        $type = 'application/octet-stream'

        if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $status = '403 Forbidden'
            $body = [System.Text.Encoding]::UTF8.GetBytes('403 Forbidden')
            $type = 'text/plain; charset=utf-8'
        } elseif ($method -ne 'GET' -and $method -ne 'HEAD') {
            $status = '405 Method Not Allowed'
            $body = [System.Text.Encoding]::UTF8.GetBytes('405 Method Not Allowed')
            $type = 'text/plain; charset=utf-8'
        } elseif (Test-Path -LiteralPath $full -PathType Container) {
            $full = Join-Path $full 'index.html'
            if (Test-Path -LiteralPath $full -PathType Leaf) {
                $body = [System.IO.File]::ReadAllBytes($full)
                $type = $mime[[System.IO.Path]::GetExtension($full).ToLowerInvariant()]
            } else {
                $status = '404 Not Found'
                $body = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
                $type = 'text/plain; charset=utf-8'
            }
        } elseif (Test-Path -LiteralPath $full -PathType Leaf) {
            $body = [System.IO.File]::ReadAllBytes($full)
            $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
            if ($mime.ContainsKey($ext)) { $type = $mime[$ext] }
        } else {
            $status = '404 Not Found'
            $body = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
            $type = 'text/plain; charset=utf-8'
        }

        $head = "HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
        $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
        $stream.Write($headBytes, 0, $headBytes.Length)
        if ($method -ne 'HEAD' -and $body.Length -gt 0) {
            $stream.Write($body, 0, $body.Length)
        }
        $stream.Flush()
    } catch {
        # ignore broken pipes / cancelled requests
    } finally {
        try { $client.Close() } catch { }
    }
}
