<#
.SYNOPSIS
  Reinitialise proprement le reseau Windows 11 (DNS, ARP, NetBIOS, Winsock, pile TCP/IP,
  services et cartes reseau, bail DHCP). Journal detaille horodate.

.PARAMETER Force
  N'affiche pas la demande de confirmation initiale ni les pauses (usage non interactif).

.PARAMETER FlushRoutes
  Vide aussi la table de routage (route -f). Supprime la passerelle par defaut :
  avec une IP statique, la connexion ne revient qu'apres redemarrage.

.PARAMETER NoRestartPrompt
  Ne propose pas de redemarrer le PC a la fin.

.PARAMETER OutputPath
  Dossier des journaux. Par defaut le dossier du script.

.NOTES
  Droits administrateur requis. Un redemarrage est necessaire pour finaliser
  la reinitialisation de Winsock et de la pile TCP/IP.

.EXAMPLE
  .\Reset-Reseau-Windows11.ps1 -Force -NoRestartPrompt
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$FlushRoutes,
    [switch]$NoRestartPrompt,
    [string]$OutputPath = $PSScriptRoot
)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Ce script necessite les droits administrateur !' -ForegroundColor Red
    Write-Host "Relancez PowerShell en tant qu'administrateur." -ForegroundColor Yellow
    exit 1
}

if (-not $OutputPath) { $OutputPath = (Get-Location).Path }
$null = New-Item -Path $OutputPath -ItemType Directory -Force
$runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $OutputPath "Reset-Reseau_$runStamp.log"
$script:failures = 0
$script:warnings = 0

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    $logMessage = "[$(Get-Date -Format 'HH:mm:ss')] [$($Type.ToUpper())] $Message"
    $color = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }[$Type]
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -LiteralPath $logFile -Value $logMessage -Encoding UTF8
}

# Execute une etape : capture la sortie dans le journal et verifie le code de sortie des commandes natives.
# Les cmdlets doivent utiliser -ErrorAction Stop pour que leurs erreurs soient interceptees.
function Invoke-Step {
    param(
        [string]$Description,
        [scriptblock]$Command,
        [switch]$ContinueOnError
    )
    Write-Log "Execution : $Description"
    try {
        $global:LASTEXITCODE = 0
        $output = (& $Command 2>&1 | Out-String).Trim()
        if ($output) { Add-Content -LiteralPath $logFile -Value $output -Encoding UTF8 }
        if ($LASTEXITCODE -ne 0) { throw "code de sortie $LASTEXITCODE" }
        Write-Log "SUCCES : $Description" -Type Success
    }
    catch {
        if ($ContinueOnError) {
            $script:warnings++
            Write-Log "ATTENTION : $Description - $($_.Exception.Message) (non bloquant)" -Type Warning
        }
        else {
            $script:failures++
            Write-Log "ERREUR : $Description - $($_.Exception.Message)" -Type Error
        }
    }
}

function Wait-UserExit {
    if (-not $Force) { $null = Read-Host 'Appuyez sur Entree pour quitter' }
}

Write-Host "`n====================================================================" -ForegroundColor Cyan
Write-Host 'REINITIALISATION DU RESEAU WINDOWS 11' -ForegroundColor Cyan
Write-Host "Log : $logFile" -ForegroundColor Cyan
Write-Host '====================================================================' -ForegroundColor Cyan

if (-not $Force) {
    Write-Host "`nCe script va :" -ForegroundColor White
    Write-Host '  - Vider les caches DNS, ARP et NetBIOS' -ForegroundColor Gray
    Write-Host '  - Reinitialiser Winsock et la pile TCP/IP (IPv4 et IPv6)' -ForegroundColor Gray
    if ($FlushRoutes) { Write-Host '  - Vider la table de routage' -ForegroundColor Gray }
    Write-Host '  - Redemarrer les services DHCP et Connexions reseau' -ForegroundColor Gray
    Write-Host '  - Redemarrer les cartes reseau physiques actives' -ForegroundColor Gray
    Write-Host "  - Renouveler l'adresse IP DHCP et reenregistrer le DNS" -ForegroundColor Gray
    Write-Host "`nATTENTION : la connexion reseau sera temporairement interrompue !" -ForegroundColor Yellow
    Write-Host 'Les connexions actives (VPN, bureau a distance, transferts) seront coupees.' -ForegroundColor Yellow
    Write-Host 'Les parametres IP statiques et proxy WinHTTP peuvent devoir etre ressaisis apres redemarrage.' -ForegroundColor Yellow

    $confirmation = Read-Host "`nEtes-vous sur de vouloir continuer ? (oui/non)"
    if ($confirmation -notmatch '^(o|oui)$') {
        Write-Log 'Script annule par l''utilisateur' -Type Warning
        Wait-UserExit
        exit 0
    }
}

Write-Log 'Debut de la reinitialisation du reseau'

# Sauvegarde de la configuration avant modification (utile pour ressaisir une IP statique)
$backupFile = Join-Path $OutputPath "Reset-Reseau_${runStamp}_config-avant.txt"
& ipconfig.exe /all | Out-File -LiteralPath $backupFile -Encoding UTF8
Write-Log "Configuration initiale sauvegardee : $backupFile"

Write-Host "`n[1] Vidage du cache DNS..." -ForegroundColor White
Invoke-Step 'Vider le cache DNS' { Clear-DnsClientCache -ErrorAction Stop }

Write-Host "`n[2] Vidage de la table ARP..." -ForegroundColor White
Invoke-Step 'Vider la table ARP' { netsh.exe interface ip delete arpcache } -ContinueOnError

Write-Host "`n[3] Rechargement du cache NetBIOS..." -ForegroundColor White
Invoke-Step 'Purge NetBIOS (nbtstat -R)' { nbtstat.exe -R } -ContinueOnError

Write-Host "`n[4] Reinitialisation de Winsock..." -ForegroundColor White
Invoke-Step 'Reinitialiser Winsock' { netsh.exe winsock reset }

# netsh int ip reset signale souvent un "Acces refuse" sur une cle protegee sans consequence : non bloquant
Write-Host "`n[5] Reinitialisation de la pile TCP/IP v4..." -ForegroundColor White
Invoke-Step 'Reinitialiser TCP/IP v4' { netsh.exe int ipv4 reset (Join-Path $OutputPath "netsh-ipv4-reset_$runStamp.log") } -ContinueOnError

Write-Host "`n[6] Reinitialisation de la pile TCP/IP v6..." -ForegroundColor White
Invoke-Step 'Reinitialiser TCP/IP v6' { netsh.exe int ipv6 reset (Join-Path $OutputPath "netsh-ipv6-reset_$runStamp.log") } -ContinueOnError

if ($FlushRoutes) {
    Write-Host "`n[7] Vidage de la table de routage..." -ForegroundColor White
    Invoke-Step 'Vider la table de routage' { route.exe -f }
}

Write-Host "`n[8] Redemarrage des services reseau..." -ForegroundColor White
Invoke-Step 'Redemarrer le service Client DHCP' { Restart-Service -Name 'Dhcp' -Force -ErrorAction Stop } -ContinueOnError
Invoke-Step 'Redemarrer le service Connexions reseau' { Restart-Service -Name 'Netman' -Force -ErrorAction Stop } -ContinueOnError

Write-Host "`n[9] Redemarrage des cartes reseau physiques actives..." -ForegroundColor White
Invoke-Step 'Redemarrer les cartes reseau' {
    $adapters = Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up'
    if ($adapters) {
        $adapters | Restart-NetAdapter -Confirm:$false -ErrorAction Stop
        "Cartes redemarrees : $(($adapters.Name) -join ', ')"
        Start-Sleep -Seconds 5
    }
    else { 'Aucune carte physique active.' }
} -ContinueOnError

Write-Host "`n[10] Renouvellement de l'adresse IP DHCP..." -ForegroundColor White
Invoke-Step 'Liberer le bail DHCP' { ipconfig.exe /release } -ContinueOnError
Start-Sleep -Seconds 2
Invoke-Step 'Renouveler le bail DHCP' { ipconfig.exe /renew } -ContinueOnError

Write-Host "`n[11] Reenregistrement DNS..." -ForegroundColor White
Invoke-Step 'Reenregistrer le DNS (ipconfig /registerdns)' { ipconfig.exe /registerdns } -ContinueOnError

Write-Host "`n[12] Configuration reseau actuelle :" -ForegroundColor White
Write-Log '--- Configuration reseau actuelle ---'
$ipConfig = & ipconfig.exe
$ipConfig | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
Add-Content -LiteralPath $logFile -Value $ipConfig -Encoding UTF8

Write-Host ''
if ($script:failures -gt 0) {
    Write-Host '====================================================================' -ForegroundColor Red
    Write-Log "REINITIALISATION TERMINEE AVEC $($script:failures) ERREUR(S) ET $($script:warnings) AVERTISSEMENT(S)" -Type Error
    Write-Host '====================================================================' -ForegroundColor Red
}
else {
    Write-Host '====================================================================' -ForegroundColor Green
    Write-Log "REINITIALISATION TERMINEE ($($script:warnings) avertissement(s) non bloquant(s))" -Type Success
    Write-Host '====================================================================' -ForegroundColor Green
}

Write-Host "`nLog sauvegarde dans : $logFile" -ForegroundColor Yellow
Write-Host 'Note : un redemarrage du PC est necessaire pour finaliser la reinitialisation de Winsock/TCP-IP.' -ForegroundColor Yellow

if (-not $NoRestartPrompt) {
    $restart = Read-Host 'Redemarrer maintenant ? (O/N)'
    if ($restart -match '^(o|oui)$') {
        Write-Log 'Redemarrage du PC initie par l''utilisateur'
        & shutdown.exe /r /t 30 /c 'Reinitialisation du reseau - Redemarrage du PC'
        Write-Host "`nRedemarrage dans 30 secondes (annulation : shutdown /a)." -ForegroundColor Magenta
        exit $(if ($script:failures -gt 0) { 1 } else { 0 })
    }
}

Wait-UserExit
exit $(if ($script:failures -gt 0) { 1 } else { 0 })
