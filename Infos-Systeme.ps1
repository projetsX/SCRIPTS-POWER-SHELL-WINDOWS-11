<#
.SYNOPSIS
  Récupère un résumé matériel/logiciel du poste (OS, CPU, RAM, GPU, firmware, sécurité, disques,
  réseau et pilotes, applications installées) et l'enregistre dans un fichier .txt horodaté.

.PARAMETER OutputPath
  Dossier du fichier de résultats. Par défaut le dossier du script.

.PARAMETER SkipApps
  N'inclut pas la liste des applications installées.

.NOTES
  Aucun module additionnel. Droits administrateur recommandés (TPM, Secure Boot).
#>

[CmdletBinding()]
param(
    [string]$OutputPath = $PSScriptRoot,
    [switch]$SkipApps
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Exécuté sans droits administrateur : l'état TPM et Secure Boot peut être indisponible."
}

if (-not $OutputPath) { $OutputPath = (Get-Location).Path }
$null = New-Item -Path $OutputPath -ItemType Directory -Force
$outFile = Join-Path $OutputPath ("Infos-Systeme_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Section {
    param([string]$Title, $Data)
    $text = ($Data | Out-String -Width 4096).Trim()
    Add-Content -LiteralPath $outFile -Value @("=== $Title ===", $text, '') -Encoding UTF8
    Write-Host "=== $Title ===" -ForegroundColor Cyan
    Write-Host $text
    Write-Host ''
}

Add-Content -LiteralPath $outFile -Encoding UTF8 -Value @(
    "=== Résumé système - $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') ==="
    "Ordinateur : $env:COMPUTERNAME"
    "Utilisateur : $env:USERDOMAIN\$env:USERNAME"
    "PowerShell : $($PSVersionTable.PSVersion)"
    ''
)

# OS
$os = Get-CimInstance Win32_OperatingSystem
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$uptime = (Get-Date) - $os.LastBootUpTime
Write-Section 'Système d''exploitation' ([PSCustomObject]@{
        Nom              = $os.Caption
        Version          = $cv.DisplayVersion
        Build            = "$($os.BuildNumber).$($cv.UBR)"
        Architecture     = $os.OSArchitecture
        Installation     = $os.InstallDate
        DernierDemarrage = $os.LastBootUpTime
        Uptime           = '{0} j {1} h {2} min' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    } | Format-List)

# Matériel
$cs = Get-CimInstance Win32_ComputerSystem
Write-Section 'Ordinateur' ([PSCustomObject]@{
        Fabricant = $cs.Manufacturer
        Modele    = $cs.Model
        RAM_GB    = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        Domaine   = if ($cs.PartOfDomain) { $cs.Domain } else { "Groupe de travail : $($cs.Workgroup)" }
    } | Format-List)

Write-Section 'Processeur' (Get-CimInstance Win32_Processor |
        Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List)

Write-Section 'Barrettes mémoire' (Get-CimInstance Win32_PhysicalMemory |
        Select-Object BankLabel, DeviceLocator, Manufacturer, PartNumber,
        @{ Name = 'CapaciteGB'; Expression = { [math]::Round($_.Capacity / 1GB, 0) } },
        @{ Name = 'VitesseMHz'; Expression = { $_.ConfiguredClockSpeed } } | Format-Table -AutoSize)

Write-Section 'Carte(s) graphique(s)' (Get-CimInstance Win32_VideoController |
        Select-Object Name, DriverVersion, DriverDate,
        @{ Name = 'Resolution'; Expression = { if ($_.CurrentHorizontalResolution) { "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)" } } } |
        Format-Table -AutoSize)

# Firmware et sécurité
$bios = Get-CimInstance Win32_BIOS
$secureBoot = try { if (Confirm-SecureBootUEFI -ErrorAction Stop) { 'Activé' } else { 'Désactivé' } } catch { 'Indisponible (BIOS legacy ou droits admin requis)' }
$tpm = try {
    $t = Get-Tpm -ErrorAction Stop
    if ($t.TpmPresent) { "Présent, prêt : $($t.TpmReady)" } else { 'Absent' }
} catch { 'Indisponible (droits admin requis)' }
$bitlocker = try {
    (Get-BitLockerVolume -ErrorAction Stop | ForEach-Object { "$($_.MountPoint) $($_.ProtectionStatus)" }) -join ', '
} catch { 'Indisponible (droits admin requis ou non pris en charge)' }
Write-Section 'Firmware et sécurité' ([PSCustomObject]@{
        BIOS_Fabricant = $bios.Manufacturer
        BIOS_Version   = $bios.SMBIOSBIOSVersion
        BIOS_Date      = $bios.ReleaseDate
        SecureBoot     = $secureBoot
        TPM            = $tpm
        BitLocker      = $bitlocker
    } | Format-List)

# Disques
Write-Section 'Disques physiques' (Get-PhysicalDisk | Sort-Object { [int]$_.DeviceId } |
        Select-Object DeviceId, FriendlyName, SerialNumber, MediaType, BusType,
        @{ Name = 'TailleGB'; Expression = { [math]::Round($_.Size / 1GB, 0) } }, HealthStatus | Format-Table -AutoSize)

Write-Section 'Volumes' (Get-Volume | Where-Object { $_.DriveLetter -and $_.Size -gt 0 } | Sort-Object DriveLetter |
        Select-Object DriveLetter, FileSystemLabel, FileSystem,
        @{ Name = 'LibreGB'; Expression = { [math]::Round($_.SizeRemaining / 1GB, 1) } },
        @{ Name = 'TotalGB'; Expression = { [math]::Round($_.Size / 1GB, 1) } } | Format-Table -AutoSize)

# Réseau
Write-Section 'Cartes réseau et pilotes' (Get-NetAdapter | Sort-Object Name |
        Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed, DriverVersion,
        @{ Name = 'DriverDate'; Expression = { $_.DriverDate } } | Format-Table -AutoSize)

Write-Section 'Adresses IPv4' (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' } |
        Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin | Format-Table -AutoSize)

# Applications installées (machine 64/32 bits + utilisateur courant), fichier uniquement
if (-not $SkipApps) {
    $apps = Get-ItemProperty -Path @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    ) -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 -and -not $_.ParentKeyName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Sort-Object DisplayName, DisplayVersion -Unique

    Add-Content -LiteralPath $outFile -Encoding UTF8 -Value @(
        "=== Applications installées ($(@($apps).Count)) ==="
        ($apps | Format-Table -AutoSize | Out-String -Width 4096).Trim()
    )
    Write-Host "Applications installées : $(@($apps).Count) (liste dans le fichier)" -ForegroundColor Cyan
}

Write-Host "Fichier généré : $outFile" -ForegroundColor Green
