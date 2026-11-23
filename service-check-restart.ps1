<#
.SYNOPSIS
  Vérifie l'état d'un service Windows et propose (ou force) son redémarrage.

.PARAMETER ServiceName
  Nom court ou nom complet du service (ex : wuauserv, bits, "Windows Update").
  Les caractères génériques (*, ?) sont refusés pour éviter d'agir sur plusieurs services.

.PARAMETER Force
  Redémarre sans demander de confirmation.

.PARAMETER TimeoutSeconds
  Délai d'attente du nouvel état du service (par défaut 30 s).

.EXAMPLE
  .\service-check-restart.ps1 -ServiceName bits
.EXAMPLE
  .\service-check-restart.ps1 -ServiceName Spooler -Force -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceName,

    [switch]$Force,

    [ValidateRange(1, 600)]
    [int]$TimeoutSeconds = 30
)

if ([WildcardPattern]::ContainsWildcardCharacters($ServiceName)) {
    Write-Error "Les caractères génériques ne sont pas autorisés : $ServiceName"
    exit 1
}

$s = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $s) { $s = Get-Service -DisplayName $ServiceName -ErrorAction SilentlyContinue }
if (-not $s) {
    Write-Error "Service introuvable : $ServiceName"
    exit 1
}

$running = $s.Status -eq 'Running'
Write-Host "Service    : $($s.Name) ($($s.DisplayName))"
Write-Host "Etat       : $($s.Status)" -ForegroundColor $(if ($running) { 'Green' } else { 'Yellow' })
Write-Host "Démarrage  : $($s.StartType)"
$dependents = @($s.DependentServices | Where-Object Status -eq 'Running')
if ($dependents) {
    Write-Host "Dépendants actifs (seront aussi redémarrés) : $($dependents.Name -join ', ')" -ForegroundColor Yellow
}

if ($s.StartType -eq 'Disabled') {
    Write-Warning 'Le service est désactivé : il ne peut pas être démarré.'
    exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Sans droits administrateur, l'opération risque d'échouer (accès refusé)."
}

$verb = if ($running) { 'redémarrer' } else { 'démarrer' }
if (-not $Force -and -not $WhatIfPreference) {
    if ((Read-Host "Souhaites-tu $verb $($s.Name) ? (o/N)") -notmatch '^(o|oui)$') {
        Write-Host 'Aucune action effectuée.'
        exit 0
    }
}

if ($PSCmdlet.ShouldProcess($s.Name, $verb)) {
    try {
        if ($running) {
            Restart-Service -InputObject $s -Force -ErrorAction Stop
        } else {
            Start-Service -InputObject $s -ErrorAction Stop
        }
        $s.WaitForStatus('Running', [TimeSpan]::FromSeconds($TimeoutSeconds))
        $s.Refresh()
        Write-Host "Opération terminée. Etat : $($s.Status)" -ForegroundColor Green
    } catch [System.ServiceProcess.TimeoutException] {
        $s.Refresh()
        Write-Error "Le service n'a pas atteint l'état Running en $TimeoutSeconds s (état : $($s.Status))."
        exit 1
    } catch {
        Write-Error "Erreur lors de l'opération : $($_.Exception.Message)"
        exit 1
    }
}
