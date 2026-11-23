<#
.SYNOPSIS
  Récupère l'état de santé des disques (espace, état physique, compteurs de fiabilité, SMART).
  Les résultats sont affichés en console et enregistrés dans un fichier .txt horodaté.

.PARAMETER OutputPath
  Dossier du fichier de résultats. Par défaut le dossier du script.

.PARAMETER WarnPercent
  Seuil d'occupation (%) déclenchant une alerte sur un volume. Par défaut 90.

.NOTES
  Exécuter en tant qu'administrateur pour les compteurs de fiabilité et les données SMART.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = $PSScriptRoot,

    [ValidateRange(1, 100)]
    [int]$WarnPercent = 90
)

if (-not $OutputPath) { $OutputPath = (Get-Location).Path }
$null = New-Item -Path $OutputPath -ItemType Directory -Force
$logFile = Join-Path $OutputPath ("Infos-sante-disque_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log {
    param([string]$Message = '', [ConsoleColor]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
    Add-Content -LiteralPath $logFile -Value $Message -Encoding UTF8
}

function Write-Block {
    param([Parameter(ValueFromPipeline)]$InputObject)
    begin { $items = @() }
    process { $items += $InputObject }
    end {
        $text = ($items | Out-String -Width 4096).TrimEnd()
        if ($text) {
            Write-Host $text
            Add-Content -LiteralPath $logFile -Value $text -Encoding UTF8
        }
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Log '=== INFORMATIONS SANTE DISQUE ===' Cyan
Write-Log "Généré le : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" Gray
if (-not $isAdmin) {
    Write-Log 'AVERTISSEMENT : exécuté sans droits administrateur. Compteurs de fiabilité et SMART probablement indisponibles.' Yellow
}
Write-Log

# === VOLUMES ===
Write-Log '=== VOLUMES ===' Cyan
$volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.Size -gt 0 } | Sort-Object DriveLetter | Select-Object `
    DriveLetter,
    FileSystemLabel,
    FileSystem,
    HealthStatus,
    @{ Name = 'LibreGB'; Expression = { [math]::Round($_.SizeRemaining / 1GB, 2) } },
    @{ Name = 'TotalGB'; Expression = { [math]::Round($_.Size / 1GB, 2) } },
    @{ Name = '%Utilisé'; Expression = { [math]::Round((($_.Size - $_.SizeRemaining) / $_.Size) * 100, 1) } }

if ($volumes) {
    $volumes | Format-Table -AutoSize | Write-Block
    foreach ($v in $volumes | Where-Object { $_.'%Utilisé' -ge $WarnPercent }) {
        Write-Log ("ALERTE : le volume {0}: est rempli à {1} %." -f $v.DriveLetter, $v.'%Utilisé') Red
    }
} else {
    Write-Log 'AVERTISSEMENT : aucun volume avec lettre de lecteur trouvé.' Yellow
}
Write-Log

# === DISQUES PHYSIQUES ===
Write-Log '=== DISQUES PHYSIQUES ===' Cyan
$disks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Sort-Object { [int]$_.DeviceId })
if ($disks) {
    $disks | Select-Object DeviceId, FriendlyName, MediaType, BusType,
        @{ Name = 'TailleGB'; Expression = { [math]::Round($_.Size / 1GB, 0) } },
        HealthStatus, OperationalStatus |
        Format-Table -AutoSize | Write-Block
    foreach ($d in $disks | Where-Object { "$($_.HealthStatus)" -ne 'Healthy' }) {
        Write-Log ("ALERTE : disque {0} ({1}) état {2} / {3}" -f $d.DeviceId, $d.FriendlyName, $d.HealthStatus, ($d.OperationalStatus -join ', ')) Red
    }
} else {
    Write-Log 'Aucun disque physique détecté.' Yellow
}
Write-Log

# === COMPTEURS DE FIABILITE (NVMe et SATA) ===
Write-Log '=== COMPTEURS DE FIABILITE ===' Cyan
$counters = foreach ($d in $disks) {
    $c = $d | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if ($c) {
        [PSCustomObject]@{
            DeviceId          = $d.DeviceId
            Disque            = $d.FriendlyName
            'Temp(C)'         = $c.Temperature
            'TempMax(C)'      = $c.TemperatureMax
            'Usure(%)'        = $c.Wear
            HeuresMarche      = $c.PowerOnHours
            ErreursLectureNC  = $c.ReadErrorsUncorrected
            ErreursEcritureNC = $c.WriteErrorsUncorrected
        }
    }
}
if ($counters) {
    $counters | Format-Table -AutoSize | Write-Block
    Write-Log 'Usure : pourcentage de durée de vie consommée (SSD). NC = non corrigées.' Gray
} elseif ($isAdmin) {
    Write-Log 'Compteurs de fiabilité non fournis par les contrôleurs de ce système.' Yellow
} else {
    Write-Log 'Compteurs de fiabilité indisponibles : droits administrateur requis.' Yellow
}
Write-Log

# === PREDICTION SMART (WMI) ===
Write-Log '=== PREDICTION DE PANNE SMART ===' Cyan
try {
    $smart = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop)
    if ($smart) {
        foreach ($s in $smart) {
            if ($s.PredictFailure) {
                Write-Log ("{0} : ALERTE - panne prédite (code {1})" -f $s.InstanceName, $s.Reason) Red
            } else {
                Write-Log ("{0} : OK" -f $s.InstanceName) Green
            }
        }
    } else {
        Write-Log 'Aucun disque ne remonte de statut SMART via WMI.' Yellow
    }
} catch {
    if ($isAdmin) {
        Write-Log 'SMART non disponible via WMI (fréquent avec NVMe ou contrôleurs RAID) : voir les compteurs de fiabilité ci-dessus.' Yellow
    } else {
        Write-Log 'Droits insuffisants pour interroger SMART. Exécutez le script en tant qu''administrateur.' Yellow
    }
}

Write-Log
Write-Log "Fichier enregistré : $logFile" Gray
