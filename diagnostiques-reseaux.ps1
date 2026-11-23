<#
.SYNOPSIS
  Lance une série de contrôles réseau : adaptateurs, IP, passerelle, DNS, connectivité, traceroute.
  Les résultats sont affichés en console et enregistrés dans un fichier .txt horodaté.

.PARAMETER HostToTest
  Hôte cible (nom DNS ou IP). Par défaut 8.8.8.8.

.PARAMETER Port
  Port TCP optionnel à tester sur l'hôte cible (ex : 443). Sans port, un ping ICMP est effectué.

.PARAMETER DnsName
  Nom utilisé pour tester la résolution DNS. Par défaut www.microsoft.com.

.PARAMETER SkipTraceroute
  Ne lance pas le traceroute (plus rapide).

.PARAMETER OutputPath
  Dossier du fichier de résultats. Par défaut le dossier du script.

.EXAMPLE
  .\diagnostiques-reseaux.ps1 -HostToTest github.com -Port 443
#>

[CmdletBinding()]
param(
  [ValidatePattern('^[A-Za-z0-9\.\-:]+$')]
  [string]$HostToTest = '8.8.8.8',

  [ValidateRange(1, 65535)]
  [int]$Port,

  [ValidatePattern('^[A-Za-z0-9\.\-]+$')]
  [string]$DnsName = 'www.microsoft.com',

  [switch]$SkipTraceroute,

  [string]$OutputPath = $PSScriptRoot
)

if (-not $OutputPath) { $OutputPath = (Get-Location).Path }
$null = New-Item -Path $OutputPath -ItemType Directory -Force
$logFile = Join-Path $OutputPath ("diagnostiques-reseaux_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

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

Write-Log '=== DIAGNOSTICS RESEAU ===' Cyan
Write-Log "Généré le : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" Gray
Write-Log "Hôte de test : $HostToTest$(if ($Port) { ":$Port" })" Gray
Write-Log

Write-Log '--- Adaptateurs réseau ---' Cyan
Get-NetAdapter | Sort-Object Status, Name |
  Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress |
  Format-Table -AutoSize | Write-Block

Write-Log
Write-Log '--- Adresses IPv4 ---' Cyan
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '127.*' } |
  Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin |
  Format-Table -AutoSize | Write-Block

Write-Log
Write-Log '--- Passerelle(s) par défaut ---' Cyan
$gateways = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric
if ($gateways) {
  foreach ($gw in $gateways) {
    $reachable = Test-Connection -ComputerName $gw.NextHop -Count 2 -Quiet -ErrorAction SilentlyContinue
    $color = if ($reachable) { 'Green' } else { 'Red' }
    Write-Log ("{0} via {1} (métrique {2}) : {3}" -f $gw.InterfaceAlias, $gw.NextHop, $gw.RouteMetric, $(if ($reachable) { 'joignable' } else { 'injoignable' })) $color
  }
} else {
  Write-Log 'Aucune passerelle par défaut configurée.' Red
}

Write-Log
Write-Log '--- Serveurs DNS ---' Cyan
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.ServerAddresses } |
  Select-Object InterfaceAlias, @{ Name = 'ServerAddresses'; Expression = { $_.ServerAddresses -join ', ' } } |
  Format-Table -AutoSize | Write-Block

Write-Log
Write-Log "--- Résolution DNS de $DnsName ---" Cyan
try {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $answers = Resolve-DnsName -Name $DnsName -DnsOnly -ErrorAction Stop | Where-Object { $_.Type -in 'A', 'AAAA' }
  $sw.Stop()
  Write-Log ("Résolu en {0} ms : {1}" -f $sw.ElapsedMilliseconds, (($answers.IPAddress | Select-Object -Unique) -join ', ')) Green
} catch {
  Write-Log "ECHEC de la résolution : $($_.Exception.Message)" Red
}

Write-Log
if ($Port) {
  Write-Log "--- Test TCP vers ${HostToTest}:$Port ---" Cyan
  Test-NetConnection -ComputerName $HostToTest -Port $Port -InformationLevel Detailed -WarningAction SilentlyContinue | Write-Block
} else {
  Write-Log "--- Test ICMP (ping) vers $HostToTest ---" Cyan
  Test-NetConnection -ComputerName $HostToTest -InformationLevel Detailed -WarningAction SilentlyContinue | Write-Block
}

if (-not $SkipTraceroute) {
  Write-Log
  Write-Log "--- Traceroute vers $HostToTest (sans résolution de noms) ---" Cyan
  & tracert.exe -d -w 1000 $HostToTest | ForEach-Object { Write-Log $_ }
}

Write-Log
Write-Log "Fichier enregistré : $logFile" Gray
