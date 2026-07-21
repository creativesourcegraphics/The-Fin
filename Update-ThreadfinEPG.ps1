<#
    Update-ThreadfinEPG.ps1
    Downloads US EPG (XMLTV) files from epgshare01.online, decompresses them,
    and drops the plain .xml files into a folder Threadfin can read.

    Usage:
        Right-click > Run with PowerShell
        (or)  powershell -ExecutionPolicy Bypass -File .\Update-ThreadfinEPG.ps1

    Schedule it: Task Scheduler > Create Basic Task > Daily > Start a program:
        powershell.exe
        Arguments: -ExecutionPolicy Bypass -File "D:\Threadfin\Update-ThreadfinEPG.ps1"
#>

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---- Config -------------------------------------------------------------
$DestFolder = 'D:\Threadfin\epg'
$BaseUrl    = 'https://epgshare01.online/epgshare01/'

# Files to grab. Comment out any you don't want. US_LOCALS1 is large (~58MB).
$Files = @(
    'epg_ripper_US1.xml.gz',          # may not always exist - skipped if 404
    'epg_ripper_US2.xml.gz',          # national US channels
    'epg_ripper_US_LOCALS1.xml.gz',   # local affiliates (large)
    'epg_ripper_US_SPORTS1.xml.gz'    # US sports
    # 'epg_ripper_PLEX1.xml.gz',      # uncomment if you carry Plex live channels
    # 'epg_ripper_PEACOCK1.xml.gz',   # uncomment for Peacock
    # 'epg_ripper_DUMMY_CHANNELS.xml.gz'
)
# ------------------------------------------------------------------------

if (-not (Test-Path $DestFolder)) {
    New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null
}

function Expand-Gz {
    param([string]$InFile, [string]$OutFile)
    $in  = [System.IO.File]::OpenRead($InFile)
    $out = [System.IO.File]::Create($OutFile)
    $gz  = New-Object System.IO.Compression.GzipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
    try   { $gz.CopyTo($out) }
    finally { $gz.Dispose(); $out.Dispose(); $in.Dispose() }
}

$ok = 0; $skip = 0
foreach ($f in $Files) {
    $url    = $BaseUrl + $f
    $gzPath = Join-Path $DestFolder $f
    $xmlOut = Join-Path $DestFolder ($f -replace '\.gz$','')

    Write-Host "-> $f" -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $url -OutFile $gzPath -UseBasicParsing `
            -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -TimeoutSec 300
        Expand-Gz -InFile $gzPath -OutFile $xmlOut
        Remove-Item $gzPath -Force
        $size = [math]::Round((Get-Item $xmlOut).Length / 1MB, 1)
        Write-Host "   OK  -> $xmlOut  (${size} MB)" -ForegroundColor Green
        $ok++
    }
    catch {
        Write-Host "   SKIP ($($_.Exception.Message))" -ForegroundColor Yellow
        if (Test-Path $gzPath) { Remove-Item $gzPath -Force }
        $skip++
    }
}

Write-Host ""
Write-Host "Done. $ok downloaded, $skip skipped. Files are in $DestFolder" -ForegroundColor White
