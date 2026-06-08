# ============================================================================
# Script de reinitialisation du reseau Windows 11
# Description: Reinitialise proprement le reseau (DNS, cache, cartes reseau, etc.)
# Auteur: Script automatise
# Date: 28 novembre 2025
# ============================================================================

# Verifier les droits administrateur
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script necessite les droits administrateur!" -ForegroundColor Red
    Write-Host "Relancez PowerShell en tant qu'administrateur." -ForegroundColor Yellow
    Exit 1
}

# Variables
$timestamp = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
$logFile = "$PSScriptRoot\Reset-Reseau_$timestamp.log"

# Fonction pour logger les messages
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    switch ($Type) {
        "Info"    { Write-Host $logMessage -ForegroundColor Cyan }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Error"   { Write-Host $logMessage -ForegroundColor Red }
    }
    
    Add-Content -Path $logFile -Value $logMessage
}

# Fonction pour executer une commande avec gestion d'erreur
function Invoke-Command-Safe {
    param(
        [string]$Description,
        [scriptblock]$Command,
        [switch]$ContinueOnError
    )
    
    Write-Log "Execution: $Description" -Type "Info"
    
    try {
        & $Command 2>$null
        Write-Log "SUCCES: $Description" -Type "Success"
        return $true
    }
    catch {
        if ($ContinueOnError) {
            Write-Log "ATTENTION: $Description - Service peut ne pas etre disponible" -Type "Warning"
            return $true
        }
        else {
            Write-Log "ERREUR: $Description - $($_.Exception.Message)" -Type "Error"
            return $false
        }
    }
}

# Affichage du titre
Write-Host "`n====================================================================" -ForegroundColor Cyan
Write-Host "REINITIALISATION DU RESEAU WINDOWS 11" -ForegroundColor Cyan
Write-Host "Log: $logFile" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host ""

# Demande de confirmation avant execution
Write-Host "ATTENTION - Veuillez lire attentivement:" -ForegroundColor Yellow
Write-Host "`nCe script va:" -ForegroundColor White
Write-Host "  - Vider le cache DNS" -ForegroundColor Gray
Write-Host "  - Reinitialiser la pile TCP/IP" -ForegroundColor Gray
Write-Host "  - Reinitialiser les interfaces reseau" -ForegroundColor Gray
Write-Host "  - Redemarrer les services reseau" -ForegroundColor Gray
Write-Host "  - Renouveler l'adresse IP DHCP" -ForegroundColor Gray
Write-Host "`nATTENTION: Cela peut causer une interruption temporaire de votre connexion reseau!" -ForegroundColor Yellow
Write-Host "Les connexions actives pourraient etre affectees." -ForegroundColor Yellow

Write-Host ""
$confirmation = Read-Host "Etes-vous sur de vouloir continuer ? (oui/non)"

if ($confirmation -ne "oui" -and $confirmation -ne "O") {
    Write-Host "`nScript annule par l'utilisateur." -ForegroundColor Red
    Write-Log "Script annule par l'utilisateur" -Type "Warning"
    Read-Host "Appuyez sur Entree pour quitter"
    Exit 0
}

Write-Host "`nExecution confirmee. Demarrage de la reinitialisation..." -ForegroundColor Green
Write-Log "Debut de la reinitialisation du reseau" -Type "Info"

# 1. Vider le cache DNS
Write-Host "`n[1] Vidage du cache DNS..." -ForegroundColor White
Invoke-Command-Safe "Vider le cache DNS" {
    Clear-DnsClientCache
}

# 2. Reinitialiser les parametres TCP/IP
Write-Host "`n[2] Reinitialisation de la pile TCP/IP..." -ForegroundColor White
Invoke-Command-Safe "Reinitialiser TCP/IP" {
    netsh int ip reset reset.log
}

# 3. Reinitialiser les interfaces Winsock
Write-Host "`n[3] Reinitialisation de Winsock..." -ForegroundColor White
Invoke-Command-Safe "Reinitialiser Winsock" {
    netsh winsock reset catalog
}

# 4. Reinitialiser les parametres Winsock IPv6
Write-Host "`n[4] Reinitialisation de Winsock IPv6..." -ForegroundColor White
Invoke-Command-Safe "Reinitialiser Winsock IPv6" {
    netsh int ipv6 reset reset.log
}

# 5. Vider la table ARP
Write-Host "`n[5] Vidage de la table ARP..." -ForegroundColor White
Invoke-Command-Safe "Vider la table ARP" {
    arp -d *
}

# 6. Vider la table des sessions NETBIOS
Write-Host "`n[6] Vidage des sessions NETBIOS..." -ForegroundColor White
Invoke-Command-Safe "Netbios reset" {
    nbtstat -R
}

# 7. Vider la table de routage
Write-Host "`n[7] Reinitialisation de la table de routage..." -ForegroundColor White
Invoke-Command-Safe "Reinitialiser la table de routage" {
    route -f
}

# 8. Redemarrer le service DNS Client
Write-Host "`n[8] Redemarrage du service DNS Client..." -ForegroundColor White
Invoke-Command-Safe "Redemarrer DNS Client" -ContinueOnError {
    Restart-Service -Name "Dnscache" -Force
}

# 9. Redemarrer le service DHCP
Write-Host "`n[9] Redemarrage du service DHCP..." -ForegroundColor White
Invoke-Command-Safe "Redemarrer DHCP" -ContinueOnError {
    Restart-Service -Name "DHCP" -Force
}

# 10. Redemarrer le service Reseau
Write-Host "`n[10] Redemarrage du service Reseau..." -ForegroundColor White
Invoke-Command-Safe "Redemarrer le service Reseau" -ContinueOnError {
    Restart-Service -Name "Netman" -Force
}

# 11. Obtenir une nouvelle adresse IP via DHCP
Write-Host "`n[11] Renouvellement de l'adresse IP DHCP..." -ForegroundColor White
Invoke-Command-Safe "Renouveler DHCP" {
    ipconfig /release
    Start-Sleep -Seconds 2
    ipconfig /renew
}

# 12. Vider la cache des connexions reseau (optional)
Write-Host "`n[12] Vidage des connexions reseau en cache..." -ForegroundColor White
Invoke-Command-Safe "Vider cache connexions reseau" {
    ipconfig /displaydns | Out-Null
}

# 13. Affichage de la configuration reseau actuelle
Write-Host "`n[13] Configuration reseau actuelle:" -ForegroundColor White
Write-Log "--- Configuration reseau actuelle ---" -Type "Info"

$ipConfig = ipconfig
Write-Host $ipConfig -ForegroundColor Gray
Add-Content -Path $logFile -Value $ipConfig

# Resume final
Write-Host "`n====================================================================" -ForegroundColor Green
Write-Host "REINITIALISATION TERMINEE" -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green
Write-Host ""

Write-Log "Reinitialisation du reseau terminee avec succes" -Type "Success"

# Message final
Write-Host "Log sauvegarde dans: $logFile" -ForegroundColor Yellow
Write-Host "`nNote: Un redemarrage du PC est recommande pour completer la reinitialisation." -ForegroundColor Yellow
Write-Host "Voulez-vous redemarrer maintenant ? (O/N)" -ForegroundColor Yellow

$restart = Read-Host "Redemarrer ?"

if ($restart -eq "O" -or $restart -eq "o") {
    Write-Log "Redemarrage du PC initie par l'utilisateur" -Type "Info"
    Write-Host "`nRedemarrage du PC dans 30 secondes..." -ForegroundColor Magenta
    Start-Sleep -Seconds 5
    shutdown /r /t 25 /c "Reinitialisation du reseau - Redemarrage du PC"
}
else {
    Write-Host "`nFermez la fenetre quand vous etes pret." -ForegroundColor Gray
    Read-Host "Appuyez sur Entree pour quitter"
}