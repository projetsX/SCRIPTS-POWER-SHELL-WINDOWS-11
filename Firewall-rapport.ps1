<#
.SYNOPSIS
  Exporte les règles du firewall en JSON et CSV.
#>

$outDir = "$env:TEMP\FirewallReport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item $outDir -ItemType Directory -Force | Out-Null

$rules = Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction SilentlyContinue | 
    Select-Object DisplayName,Name,Enabled,Direction,Action,Profile,InterfaceType

$rules | ConvertTo-Json -Depth 4 | Out-File (Join-Path $outDir "firewall_rules.json")
$rules | Export-Csv -Path (Join-Path $outDir "firewall_rules.csv") -NoTypeInformation

Write-Host "Exports : $outDir"
