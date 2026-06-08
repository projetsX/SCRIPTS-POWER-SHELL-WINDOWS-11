<#
.SYNOPSIS
  Récupère l'état SMART et l'espace disque.
  Les résultats sont affichés en console et enregistrés dans un fichier .txt.

.NOTES
  Exécuter en tant qu'administrateur pour de meilleurs résultats.
#>

# Créer le fichier de sortie avec horodatage
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptPath "Infos-sante-disque_$timestamp.txt"

# Fonction pour afficher et enregistrer
function Write-Output-And-Log {
    param([string]$message, [string]$foregroundColor = "White")
    Write-Host $message -ForegroundColor $foregroundColor
    Add-Content -Path $logFile -Value $message -Encoding UTF8
}

# Vérifier les droits administrateur
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Output-And-Log "AVERTISSEMENT: Script exécuté sans droits administrateur. Certaines informations SMART peuvent ne pas être disponibles." "Yellow"
    Write-Output-And-Log ""
}

# === ESPACE DISQUE ===
Write-Output-And-Log "=== INFORMATIONS SANTE DISQUE ===" "Cyan"
Write-Output-And-Log "Généré le : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" "Gray"
Write-Output-And-Log ""
Write-Output-And-Log "=== VOLUMES DISQUE ===" "Cyan"
Write-Output-And-Log ""

$volumes = Get-Volume | Where-Object { $_.DriveLetter } | Select-Object `
    DriveLetter, 
    FileSystemLabel, 
    FileSystem,
    @{Name='LibreGB'; Expression={[math]::Round($_.SizeRemaining / 1GB, 2)}},
    @{Name='TotalGB'; Expression={[math]::Round($_.Size / 1GB, 2)}},
    @{Name='%Utilisé'; Expression={
        if ($_.Size -gt 0) {
            [math]::Round((($_.Size - $_.SizeRemaining) / $_.Size) * 100, 1)
        } else {
            0
        }
    }}

if ($volumes) {
    $volumes | Format-Table -AutoSize | Out-String | ForEach-Object {
        if ($_.Trim()) {
            Add-Content -Path $logFile -Value $_ -Encoding UTF8
            Write-Host $_
        }
    }
} else {
    Write-Output-And-Log "AVERTISSEMENT: Aucun volume avec lettre de lecteur trouvé." "Yellow"
}

Write-Output-And-Log ""

# === INFORMATIONS SMART ===
Write-Output-And-Log "=== INFORMATIONS SMART ===" "Cyan"
Write-Output-And-Log ""

try {
    $smart = Get-WmiObject -Namespace root\wmi -Class MSStorageDriver_FailurePredictStatus -ErrorAction Stop
    
    if ($smart) {
        foreach ($s in $smart) {
            $dev = $s.InstanceName
            $status = if ($s.PredictFailure -eq $false) { "OK" } else { "ALERTE" }
            $couleur = if ($s.PredictFailure -eq $false) { "Green" } else { "Red" }
            
            Write-Output-And-Log "Périphérique: $dev" "White"
            Write-Output-And-Log "État: $status" $couleur
            Write-Output-And-Log "Risque d'échec: $($s.PredictFailure)" "Gray"
            Write-Output-And-Log ""
        }
    } else {
        Write-Output-And-Log "Aucun disque SMART détecté." "Yellow"
    }
} catch {
    if ($isAdmin) {
        Write-Output-And-Log "AVERTISSEMENT: Impossible d'interroger SMART via WMI sur ce système." "Yellow"
        Write-Output-And-Log "Cause possible: WMI non configuré ou contrôleur non supporté." "Yellow"
    } else {
        Write-Output-And-Log "AVERTISSEMENT: Droits insuffisants pour interroger SMART. Veuillez exécuter en tant qu'administrateur." "Yellow"
    }
}

Write-Output-And-Log ""
Write-Output-And-Log "Fichier enregistré : $logFile" "Gray"
