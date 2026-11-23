<#
.SYNOPSIS
  Affiche les processus les plus consommateurs (CPU ou mémoire).

.DESCRIPTION
  Le "CPU %" est mesuré sur un court intervalle (charge instantanée, tous coeurs confondus).
  "CPU (s)" est le temps processeur cumulé depuis le lancement du processus.

.PARAMETER Top
  Nombre de processus affichés (par défaut 20).

.PARAMETER SortBy
  CPU (charge instantanée) ou Memory (mémoire de travail). Par défaut CPU.

.PARAMETER SampleSeconds
  Durée de mesure de la charge CPU (1 à 60 s, par défaut 1).

.EXAMPLE
  .\Infos-topProcess.ps1 -Top 10 -SortBy Memory
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 500)]
    [int]$Top = 20,

    [ValidateSet('CPU', 'Memory')]
    [string]$SortBy = 'CPU',

    [ValidateRange(1, 60)]
    [int]$SampleSeconds = 1
)

$cores = [Environment]::ProcessorCount
$before = @{}
foreach ($p in Get-Process) {
    if ($null -ne $p.CPU) { $before[$p.Id] = $p.CPU }
}
Start-Sleep -Seconds $SampleSeconds

$rows = foreach ($p in Get-Process) {
    $cpuPct = 0
    if ($null -ne $p.CPU -and $before.ContainsKey($p.Id)) {
        $cpuPct = [math]::Round((($p.CPU - $before[$p.Id]) / $SampleSeconds / $cores) * 100, 1)
    }
    [PSCustomObject]@{
        Id             = $p.Id
        Processus      = $p.ProcessName
        'CPU %'        = $cpuPct
        'CPU (s)'      = if ($null -ne $p.CPU) { [math]::Round($p.CPU, 1) } else { $null }
        'Mémoire (MB)' = [math]::Round($p.WorkingSet64 / 1MB, 1)
        'Privée (MB)'  = [math]::Round($p.PrivateMemorySize64 / 1MB, 1)
    }
}

$sortKey = if ($SortBy -eq 'Memory') { 'Mémoire (MB)' } else { 'CPU %' }
$rows | Sort-Object -Property $sortKey, 'CPU (s)' -Descending |
    Select-Object -First $Top |
    Format-Table -AutoSize
