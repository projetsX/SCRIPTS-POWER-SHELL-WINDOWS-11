<#
.SYNOPSIS
  Liste les processus triés par consommation CPU (et mémoire).
#>

$top = 20
Get-Process | Sort-Object CPU -Descending | Select-Object -First $top -Property Id, ProcessName, CPU, WorkingSet64, @{Name = 'MemoryMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) } } |
Format-Table -AutoSize
