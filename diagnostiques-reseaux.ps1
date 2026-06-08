<#
.SYNOPSIS
  Lance une série de checks réseau utiles : adaptateurs, DNS, route vers un host, traceroute.
  Les résultats sont affichés en console et enregistrés dans un fichier .txt.

.PARAMETER HostToTest
  Host de test (par défaut 8.8.8.8).
#>

param(
  [string]$HostToTest = "8.8.8.8"
)

# Créer le fichier de sortie avec horodatage
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptPath "diagnostiques-reseaux_$timestamp.txt"

# Fonction pour afficher et enregistrer
function Write-Output-And-Log {
  param([string]$message, [string]$foregroundColor = "White")
  Write-Host $message -ForegroundColor $foregroundColor
  Add-Content -Path $logFile -Value $message -Encoding UTF8
}

Write-Output-And-Log "=== DIAGNOSTIQUES RESEAU ===" "Cyan"
Write-Output-And-Log "Généré le : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" "Gray"
Write-Output-And-Log "Host de test : $HostToTest" "Gray"
Write-Output-And-Log ""

Write-Output-And-Log "--- NetAdapter ---" "Cyan"
Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table -AutoSize | Out-String | ForEach-Object {
  if ($_.Trim()) {
    Add-Content -Path $logFile -Value $_ -Encoding UTF8
    Write-Host $_
  }
}

Write-Output-And-Log "" 
Write-Output-And-Log "--- IP Configuration ---" "Cyan"
Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias, IPAddress, PrefixLength | Out-String | ForEach-Object {
  if ($_.Trim()) {
    Add-Content -Path $logFile -Value $_ -Encoding UTF8
    Write-Host $_
  }
}

Write-Output-And-Log ""
Write-Output-And-Log "--- DNS Servers ---" "Cyan"
Get-DnsClientServerAddress | Select-Object InterfaceAlias, ServerAddresses | Format-Table -AutoSize | Out-String | ForEach-Object {
  if ($_.Trim()) {
    Add-Content -Path $logFile -Value $_ -Encoding UTF8
    Write-Host $_
  }
}

Write-Output-And-Log ""
Write-Output-And-Log "--- Test-NetConnection (TCP) vers $HostToTest ---" "Cyan"
Test-NetConnection -ComputerName $HostToTest -InformationLevel Detailed | Out-String | ForEach-Object {
  if ($_.Trim()) {
    Add-Content -Path $logFile -Value $_ -Encoding UTF8
    Write-Host $_
  }
}

Write-Output-And-Log ""
Write-Output-And-Log "--- Traceroute vers $HostToTest ---" "Cyan"
tracert $HostToTest | ForEach-Object {
  Add-Content -Path $logFile -Value $_ -Encoding UTF8
  Write-Host $_
}

Write-Output-And-Log ""
Write-Output-And-Log "Fichier enregistré : $logFile" "Gray"
