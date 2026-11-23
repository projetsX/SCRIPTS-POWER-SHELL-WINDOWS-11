<#
.SYNOPSIS
    Teste l'accessibilité des ports mail courants (SMTP, IMAP, POP3) depuis la machine locale.

.DESCRIPTION
    Vérifie la connectivité TCP vers un serveur mail :
    - SMTP : 25, 465, 587
    - IMAP : 143, 993
    - POP3 : 110, 995

    Chaque port est testé avec un délai maximal (bien plus rapide que Test-NetConnection
    sur un port filtré). Pour les ports en clair, la bannière d'accueil du serveur est affichée.
    Aucune authentification n'est effectuée.

    Code de sortie : 0 si au moins un port est ouvert, 1 sinon, 2 si le nom ne se résout pas.

.PARAMETER MailServer
    Nom DNS ou IP du serveur mail à tester (ex : smtp.gmail.com, mail.domaine.tld).

.PARAMETER TimeoutMs
    Délai maximal de connexion par port en millisecondes (par défaut 3000).

.EXAMPLE
    .\Test-Mails-Ports.ps1 -MailServer mail.mondomaine.fr
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9\.\-:]+$')]
    [string]$MailServer,

    [ValidateRange(100, 60000)]
    [int]$TimeoutMs = 3000
)

$ports = @(
    @{ Service = 'SMTP'; Port = 25;  Tls = $false; Description = 'SMTP relais (souvent bloqué par les FAI)' }
    @{ Service = 'SMTP'; Port = 465; Tls = $true;  Description = 'SMTPS (TLS implicite)' }
    @{ Service = 'SMTP'; Port = 587; Tls = $false; Description = 'Submission (STARTTLS)' }
    @{ Service = 'IMAP'; Port = 143; Tls = $false; Description = 'IMAP (STARTTLS)' }
    @{ Service = 'IMAP'; Port = 993; Tls = $true;  Description = 'IMAPS (TLS implicite)' }
    @{ Service = 'POP3'; Port = 110; Tls = $false; Description = 'POP3 (STARTTLS)' }
    @{ Service = 'POP3'; Port = 995; Tls = $true;  Description = 'POP3S (TLS implicite)' }
)

function Test-TcpPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs, [bool]$ReadBanner)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        if (-not $task.Wait($TimeoutMs)) {
            return @{ Status = 'FILTRÉ'; Banner = '(délai dépassé)' }
        }
        $banner = ''
        if ($ReadBanner) {
            try {
                $stream = $client.GetStream()
                $stream.ReadTimeout = $TimeoutMs
                $reader = New-Object System.IO.StreamReader($stream)
                $banner = $reader.ReadLine()
                # Contenu fourni par le serveur distant : suppression des caractères de contrôle (séquences ANSI)
                if ($banner) {
                    $banner = $banner -replace '[\x00-\x1F\x7F]', ''
                    if ($banner.Length -gt 200) { $banner = $banner.Substring(0, 200) }
                }
            } catch {
                $banner = '(pas de bannière)'
            }
        }
        return @{ Status = 'OUVERT'; Banner = $banner }
    } catch {
        $inner = $_.Exception.GetBaseException()
        if ($inner -is [System.Net.Sockets.SocketException] -and $inner.SocketErrorCode -eq 'ConnectionRefused') {
            return @{ Status = 'FERMÉ'; Banner = '(connexion refusée)' }
        }
        return @{ Status = 'ERREUR'; Banner = $inner.Message }
    } finally {
        $client.Dispose()
    }
}

Write-Host ''
Write-Host '==============================================='
Write-Host " Test des ports mail vers $MailServer"
Write-Host '==============================================='

try {
    $addresses = [System.Net.Dns]::GetHostAddresses($MailServer)
    Write-Host " Adresse(s) : $(($addresses.IPAddressToString) -join ', ')" -ForegroundColor Gray
} catch {
    Write-Host " Impossible de résoudre $MailServer : $($_.Exception.GetBaseException().Message)" -ForegroundColor Red
    exit 2
}
Write-Host ''

$results = foreach ($entry in $ports) {
    Write-Host "Test $($entry.Service) - Port $($entry.Port) ..." -NoNewline
    $r = Test-TcpPort -HostName $MailServer -Port $entry.Port -TimeoutMs $TimeoutMs -ReadBanner (-not $entry.Tls)
    $color = switch ($r.Status) { 'OUVERT' { 'Green' } 'ERREUR' { 'Yellow' } default { 'Red' } }
    Write-Host "  $($r.Status)" -ForegroundColor $color

    [PSCustomObject]@{
        Service     = $entry.Service
        Port        = $entry.Port
        Description = $entry.Description
        Statut      = $r.Status
        Detail      = $r.Banner
    }
}

Write-Host ''
Write-Host '================ Résumé ================'
$results | Format-Table -AutoSize -Wrap | Out-Host

if ($results.Statut -contains 'OUVERT') { exit 0 } else { exit 1 }
