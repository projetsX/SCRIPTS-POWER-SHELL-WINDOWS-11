<#
.SYNOPSIS
  Exporte les journaux Windows récents (.evtx) dans une archive .zip horodatée.

.PARAMETER Days
  Nombre de jours à remonter (1 à 3650, par défaut 7).

.PARAMETER LogName
  Journaux à exporter. Par défaut : Application, System, Security.
  Accepte aussi les journaux détaillés, ex : 'Microsoft-Windows-PowerShell/Operational'.

.PARAMETER OutputPath
  Dossier de destination. Par défaut le dossier du script.

.PARAMETER KeepFolder
  Conserve le dossier des .evtx non compressés après création de l'archive.

.NOTES
  Droits administrateur requis pour le journal Security.

.EXAMPLE
  .\export-logs.ps1 -Days 2 -LogName System, Application
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 3650)]
    [int]$Days = 7,

    [ValidateNotNullOrEmpty()]
    [string[]]$LogName = @('Application', 'System', 'Security'),

    [string]$OutputPath = $PSScriptRoot,

    [switch]$KeepFolder
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and ($LogName -contains 'Security')) {
    Write-Error "Droits administrateur requis pour exporter le journal Security. Relancez PowerShell en tant qu'administrateur ou retirez 'Security' de -LogName."
    exit 1
}

if (-not $OutputPath) { $OutputPath = (Get-Location).Path }
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$baseDir = Join-Path $OutputPath "EventLogs_$timestamp"
$null = New-Item -Path $baseDir -ItemType Directory -Force

# timediff() évite les problèmes de format de date dans la requête XPath
$query = "*[System[TimeCreated[timediff(@SystemTime) <= $([int64]$Days * 86400000)]]]"
$exported = 0

foreach ($ch in $LogName) {
    if (-not (Get-WinEvent -ListLog $ch -ErrorAction SilentlyContinue)) {
        Write-Warning "Journal introuvable : $ch"
        continue
    }
    $outfile = Join-Path $baseDir (($ch -replace '[\\/:*?"<>|]', '_') + '.evtx')
    $output = & wevtutil.exe epl $ch $outfile "/q:$query" /ow:true 2>&1
    if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $outfile)) {
        $sizeMB = [math]::Round((Get-Item -LiteralPath $outfile).Length / 1MB, 2)
        Write-Host "Exporté : $ch -> $outfile ($sizeMB MB)" -ForegroundColor Green
        $exported++
    } else {
        Write-Warning "Echec export $ch : $($output -join ' ')"
    }
}

if ($exported -eq 0) {
    Remove-Item -LiteralPath $baseDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Error 'Aucun journal exporté.'
    exit 1
}

$zip = Join-Path $OutputPath "EventLogs_$timestamp.zip"
try {
    Compress-Archive -LiteralPath (Get-ChildItem -LiteralPath $baseDir).FullName -DestinationPath $zip -Force -ErrorAction Stop
    Write-Host "Archive créée : $zip" -ForegroundColor Cyan
    if (-not $KeepFolder) { Remove-Item -LiteralPath $baseDir -Recurse -Force }
} catch {
    Write-Error "Echec de la compression : $($_.Exception.Message). Les fichiers restent dans $baseDir"
    exit 1
}
