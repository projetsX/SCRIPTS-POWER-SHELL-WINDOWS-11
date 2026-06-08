<#
.SYNOPSIS
  Exporte les journaux Windows récents dans un dossier compressé.

.PARAMETER Days
  Nombre de jours à remonter (par défaut 7).
#>

param(
    [int]$Days = 7
)

if ($Days -lt 1) { $Days = 7 }

If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
    Write-Error "Il faut exécuter ce script en tant qu'administrateur pour exporter les journaux de sécurité."
    exit 1
}

$since = (Get-Date).AddDays(-$Days)
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$baseDir = "$scriptDir\EventLogs_$timestamp"
New-Item -Path $baseDir -ItemType Directory -Force | Out-Null

$channels = @("Application","System","Security")

foreach ($ch in $channels) {
    $outfile = Join-Path $baseDir "$ch.evtx"
    wevtutil epl $ch $outfile /q:"*[System[TimeCreated[@SystemTime>='$($since.ToUniversalTime().ToString("o"))']]]" 2>$null
    if (Test-Path $outfile) { Write-Host "Exporté: $ch -> $outfile" } else { Write-Warning "Echec export $ch (peut-être pas d'events ou pas d'accès)." }
}

# compress
$zip = "$scriptDir\EventLogs_$timestamp.zip"
Compress-Archive -Path "$baseDir\*" -DestinationPath $zip -Force
Write-Host "Archive créée: $zip"
