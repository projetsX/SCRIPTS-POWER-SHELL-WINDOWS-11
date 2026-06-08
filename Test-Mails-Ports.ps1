<#
.SYNOPSIS
    Teste l'accessibilité des ports SMTP et IMAP courants depuis la machine locale.

.DESCRIPTION
    Vérifie la connectivité TCP vers un serveur mail pour les ports standards :
    - SMTP : 25, 465, 587
    - IMAP : 143, 993

    Le test utilise Test-NetConnection (TCP SYN).
    Aucune authentification n'est effectuée.

.PARAMETER MailServer
    Nom DNS ou IP du serveur mail à tester (ex: smtp.gmail.com, mail.domain.tld)

.EXAMPLE
    .\Test-MailPorts.ps1 -MailServer mail.mondomaine.fr
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$MailServer
)

# Ports standards
$ports = @(
    @{ Service = "SMTP"; Port = 25;  Description = "SMTP standard (souvent bloqué par FAI)" },
    @{ Service = "SMTP"; Port = 465; Description = "SMTPS (SSL implicite)" },
    @{ Service = "SMTP"; Port = 587; Description = "SMTP Submission (TLS)" },
    @{ Service = "IMAP"; Port = 143; Description = "IMAP standard" },
    @{ Service = "IMAP"; Port = 993; Description = "IMAPS (SSL)" },
    @{ Service = "IMAP"; Port = 995; Description = "POP 3 N°1" },
    @{ Service = "IMAP"; Port = 110; Description = "POP 3 N°2" }
)

Write-Host ""
Write-Host "==============================================="
Write-Host " Test des ports SMTP / IMAP vers $MailServer"
Write-Host "==============================================="
Write-Host ""

$results = @()

foreach ($entry in $ports) {

    Write-Host "Test $($entry.Service) - Port $($entry.Port) ..." -NoNewline

    try {
        $test = Test-NetConnection -ComputerName $MailServer -Port $entry.Port -WarningAction SilentlyContinue -ErrorAction Stop

        if ($test.TcpTestSucceeded) {
            Write-Host "  OUVERT" -ForegroundColor Green
            $status = "OUVERT"
        } else {
            Write-Host "  FERMÉ / BLOQUÉ" -ForegroundColor Red
            $status = "FERMÉ"
        }

    } catch {
        Write-Host "  ERREUR" -ForegroundColor Yellow
        $status = "ERREUR"
    }

    $results += [PSCustomObject]@{
        Service     = $entry.Service
        Port        = $entry.Port
        Description = $entry.Description
        Statut      = $status
    }
}

Write-Host ""
Write-Host "================ Résumé ================"
$results | Format-Table -AutoSize
Write-Host ""

# Code de sortie utile pour scripts automatisés
if ($results.Statut -contains "OUVERT") {
    exit 0
} else {
    exit 1
}
