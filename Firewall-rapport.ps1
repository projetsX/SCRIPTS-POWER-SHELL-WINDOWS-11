<#
.SYNOPSIS
  Exporte les règles du pare-feu Windows (stratégie active) en JSON et CSV.

.DESCRIPTION
  Inclut protocole, ports, adresses et programme associés à chaque règle.
  Le CSV utilise le séparateur de liste régional (ouverture directe dans Excel).

.PARAMETER OutputPath
  Dossier parent des exports. Par défaut %TEMP%.

.PARAMETER EnabledOnly
  N'exporte que les règles activées.

.PARAMETER BlockedOnly
  N'exporte que les règles de blocage (Action = Block) et les affiche en console
  (sens, protocole, ports, adresses distantes, programme).
  Combiner avec -EnabledOnly pour ne voir que les blocages réellement appliqués.

.EXAMPLE
  .\Firewall-rapport.ps1 -EnabledOnly -OutputPath C:\Rapports
.EXAMPLE
  .\Firewall-rapport.ps1 -BlockedOnly -EnabledOnly
#>

[CmdletBinding()]
param(
    [string]$OutputPath = $env:TEMP,
    [switch]$EnabledOnly,
    [switch]$BlockedOnly
)

$suffix = if ($BlockedOnly) { '_Bloques' } else { '' }
$outDir = Join-Path $OutputPath ("FirewallReport{0}_{1}" -f $suffix, (Get-Date -Format 'yyyyMMdd_HHmmss'))

$rules = @(Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction SilentlyContinue)
if ($EnabledOnly) { $rules = @($rules | Where-Object { $_.Enabled -eq 'True' }) }
if ($BlockedOnly) { $rules = @($rules | Where-Object { "$($_.Action)" -eq 'Block' }) }
if ($rules.Count -eq 0) {
    if ($BlockedOnly) {
        Write-Host 'Aucune règle de blocage trouvée.' -ForegroundColor Yellow
        exit 0
    }
    Write-Error 'Aucune règle de pare-feu récupérée.'
    exit 1
}
$null = New-Item -Path $outDir -ItemType Directory -Force

# Récupération groupée des filtres (beaucoup plus rapide qu'un appel par règle)
function Get-FilterIndex {
    param([scriptblock]$Command)
    $index = @{}
    foreach ($f in (& $Command)) { $index[$f.InstanceID] = $f }
    $index
}
$portIdx = Get-FilterIndex { Get-NetFirewallPortFilter -All -PolicyStore ActiveStore -ErrorAction SilentlyContinue }
$addrIdx = Get-FilterIndex { Get-NetFirewallAddressFilter -All -PolicyStore ActiveStore -ErrorAction SilentlyContinue }
$appIdx = Get-FilterIndex { Get-NetFirewallApplicationFilter -All -PolicyStore ActiveStore -ErrorAction SilentlyContinue }

$report = foreach ($r in $rules) {
    $pf = $portIdx[$r.Name]
    $af = $addrIdx[$r.Name]
    $ap = $appIdx[$r.Name]
    [PSCustomObject]@{
        DisplayName   = $r.DisplayName
        Name          = $r.Name
        Group         = $r.DisplayGroup
        Enabled       = "$($r.Enabled)"
        Direction     = "$($r.Direction)"
        Action        = "$($r.Action)"
        Profile       = "$($r.Profile)"
        Protocol      = if ($pf) { "$($pf.Protocol)" } else { '' }
        LocalPort     = if ($pf) { $pf.LocalPort -join ',' } else { '' }
        RemotePort    = if ($pf) { $pf.RemotePort -join ',' } else { '' }
        RemoteAddress = if ($af) { $af.RemoteAddress -join ',' } else { '' }
        Program       = if ($ap) { $ap.Program } else { '' }
        Source        = "$($r.PolicyStoreSourceType)"
    }
}

$report = $report | Sort-Object Direction, DisplayName
$jsonFile = Join-Path $outDir 'firewall_rules.json'
$csvFile = Join-Path $outDir 'firewall_rules.csv'
$report | ConvertTo-Json -Depth 3 | Out-File -LiteralPath $jsonFile -Encoding UTF8
$report | Export-Csv -LiteralPath $csvFile -NoTypeInformation -Encoding UTF8 -UseCulture

$enabled = @($report | Where-Object Enabled -eq 'True')
if ($BlockedOnly) {
    Write-Host "=== Règles de blocage : $($report.Count) (activées : $($enabled.Count)) ===" -ForegroundColor Cyan
    $report | Sort-Object Direction, Protocol, LocalPort |
        Select-Object @{ Name = 'Sens'; Expression = { if ($_.Direction -eq 'Inbound') { 'Entrant' } else { 'Sortant' } } },
        @{ Name = 'Active'; Expression = { $_.Enabled } },
        Protocol, LocalPort, RemotePort, RemoteAddress, Profile, Program, DisplayName |
        Format-Table -AutoSize | Out-String -Width 4096 | Out-Host
} else {
    Write-Host "Règles exportées : $($report.Count) (activées : $($enabled.Count))" -ForegroundColor Cyan
    Write-Host ("  Entrantes autorisées activées : {0}" -f @($enabled | Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' }).Count)
    Write-Host ("  Entrantes autorisées activées, toutes adresses distantes : {0}" -f @($enabled | Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' -and $_.RemoteAddress -eq 'Any' }).Count)
    Write-Host ("  Règles de blocage activées : {0}" -f @($enabled | Where-Object { $_.Action -eq 'Block' }).Count)
}
Write-Host "Exports : $outDir" -ForegroundColor Cyan
