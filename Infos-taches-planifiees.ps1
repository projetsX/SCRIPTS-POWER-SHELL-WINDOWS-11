<#
.SYNOPSIS
  Liste les tâches planifiées, et les clés Run au démarrage (HKLM/HKCU).
  Les résultats sont affichés en console et enregistrés dans un fichier .txt.
#>

# Créer le fichier de sortie avec horodatage
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptPath "Infos-taches-planifiees_$timestamp.txt"

# Fonction pour afficher et enregistrer
function Write-Output-And-Log {
    param([string]$message)
    Write-Host $message
    Add-Content -Path $logFile -Value $message -Encoding UTF8
}

Write-Output-And-Log "=== Informations sur les tâches planifiées et démarrages ==="
Write-Output-And-Log "Généré le : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Write-Output-And-Log ""

Write-Output-And-Log "--- Scheduled Tasks (Task Scheduler) ---"
$scheduledTasks = Get-ScheduledTask | Select-Object TaskName,TaskPath,State | Sort-Object TaskName
$scheduledTasks | Format-Table -AutoSize | Out-String | ForEach-Object {
    if ($_.Trim()) {
        Add-Content -Path $logFile -Value $_ -Encoding UTF8
        Write-Host $_
    }
}

Write-Output-And-Log ""
Write-Output-And-Log "--- Startup (HKLM) ---"
$hklmRun = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -ErrorAction SilentlyContinue |
    Select-Object PSChildName, *
$hklmRun | Format-Table -AutoSize | Out-String | ForEach-Object {
    if ($_.Trim()) {
        Add-Content -Path $logFile -Value $_ -Encoding UTF8
        Write-Host $_
    }
}

Write-Output-And-Log ""
Write-Output-And-Log "--- Startup (HKCU) ---"
$hkcuRun = Get-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -ErrorAction SilentlyContinue |
    Select-Object PSChildName, *
$hkcuRun | Format-Table -AutoSize | Out-String | ForEach-Object {
    if ($_.Trim()) {
        Add-Content -Path $logFile -Value $_ -Encoding UTF8
        Write-Host $_
    }
}

Write-Output-And-Log ""
Write-Output-And-Log "Fichier enregistré : $logFile"
