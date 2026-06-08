<#
.SYNOPSIS
  Récupère et affiche un résumé matériel/logiciel du poste.

.REQUIREMENTS
  - Aucun module additionnel.
#>

# Elevation check
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
    Write-Warning "Ce script est plus utile en tant qu'administrateur. Lance PowerShell en mode administrateur si possible."
}

$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile = "$scriptDir\system_overview_$timestamp.txt"

"=== System Overview - $timestamp" | Out-File $outFile
"ComputerName: $env:COMPUTERNAME" | Out-File $outFile -Append
"User: $env:USERNAME" | Out-File $outFile -Append
"" | Out-File $outFile -Append

# OS & version
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture, LastBootUpTime |
Format-List | Out-String | Out-File $outFile -Append

"" | Out-File $outFile -Append

# Hardware
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory |
Format-List | Out-String | Out-File $outFile -Append

Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed |
Format-List | Out-String | Out-File $outFile -Append

Get-CimInstance Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate |
Format-List | Out-String | Out-File $outFile -Append

# Disques
Get-PhysicalDisk | Select-Object FriendlyName, SerialNumber, MediaType, Size, HealthStatus |
Format-Table -AutoSize | Out-String | Out-File $outFile -Append

Get-Volume | Select-Object DriveLetter, FileSystem, SizeRemaining, Size |
Format-Table -AutoSize | Out-String | Out-File $outFile -Append

# Network
Get-NetAdapter | Select-Object Name, Status, MacAddress, LinkSpeed |
Format-Table -AutoSize | Out-String | Out-File $outFile -Append

Get-NetIPAddress -AddressFamily IPv4 | Select-Object InterfaceAlias, IPAddress, PrefixLength |
Format-Table -AutoSize | Out-String | Out-File $outFile -Append

# Installed programs (registry)
$apps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* , HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
"Installed applications (partial):" | Out-File $outFile -Append
$apps | Sort-Object DisplayName | Out-String | Out-File $outFile -Append

Write-Host "Fichier généré : $outFile"
