<#
.SYNOPSIS
  Vérifie l'état d'un service et propose/ou force un redémarrage.

.PARAMETER ServiceName
  Nom du service (ex: wuauserv, bits).

.PARAMETER Force
  Force le redémarrage sans confirmation.
#>

param(
    [Parameter(Mandatory = $true)][string]$ServiceName,
    [switch]$Force
)

if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    Write-Error "Service introuvable: $ServiceName"
    exit 1
}

$s = Get-Service -Name $ServiceName
Write-Host "Service: $($s.Name) - Etat: $($s.Status)"

if ($s.Status -eq 'Running') {
    Write-Host "Le service est en cours d'exécution."
}
else {
    Write-Host "Le service n'est pas démarré."
}

if ($Force -or (Read-Host "Souhaites-tu redémarrer $ServiceName ? (o/N)") -match '^[oO]') {
    try {
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
        Write-Host "Redémarrage terminé."
    }
    catch {
        Write-Error "Erreur lors du redémarrage : $_"
    }
}
