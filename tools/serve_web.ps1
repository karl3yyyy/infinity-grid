[CmdletBinding()]
param(
    [int]$Port = 8060,
    [string]$WebRoot = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not $WebRoot) {
    $WebRoot = Join-Path $ProjectRoot "build\web"
}
$WebRoot = [System.IO.Path]::GetFullPath($WebRoot)
if (-not (Test-Path -LiteralPath (Join-Path $WebRoot "index.html"))) {
    throw "Web export was not found: $WebRoot\index.html"
}

$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".js"   = "text/javascript; charset=utf-8"
    ".wasm" = "application/wasm"
    ".pck"  = "application/octet-stream"
    ".png"  = "image/png"
    ".ico"  = "image/x-icon"
}
$Listener = [System.Net.HttpListener]::new()
$Listener.Prefixes.Add("http://127.0.0.1:$Port/")
$Listener.Start()
Write-Host "Serving Tactical Slash at http://127.0.0.1:$Port/"

try {
    while ($Listener.IsListening) {
        $Context = $Listener.GetContext()
        $RequestPath = [System.Uri]::UnescapeDataString($Context.Request.Url.AbsolutePath.TrimStart("/"))
        if (-not $RequestPath) { $RequestPath = "index.html" }
        $FilePath = [System.IO.Path]::GetFullPath((Join-Path $WebRoot $RequestPath))
        if (-not $FilePath.StartsWith($WebRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $Context.Response.StatusCode = 403
            $Context.Response.Close()
            continue
        }
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            $Context.Response.StatusCode = 404
            $Context.Response.Close()
            continue
        }
        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $Extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
        $Context.Response.ContentType = $MimeTypes[$Extension]
        if (-not $Context.Response.ContentType) {
            $Context.Response.ContentType = "application/octet-stream"
        }
        $Context.Response.Headers["Cross-Origin-Opener-Policy"] = "same-origin"
        $Context.Response.Headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        $Context.Response.ContentLength64 = $Bytes.Length
        if ($Context.Request.HttpMethod -ne "HEAD") {
            $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
        }
        $Context.Response.Close()
    }
}
finally {
    $Listener.Stop()
    $Listener.Close()
}
