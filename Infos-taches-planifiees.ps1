<#
.SYNOPSIS
  Liste les tâches planifiées et les programmes lancés au démarrage (clés Run/RunOnce,
  dossiers Démarrage), avec leur état activé/désactivé dans le Gestionnaire des tâches.
  Les résultats sont affichés en console et enregistrés dans un fichier .txt horodaté.

.PARAMETER ExcludeMicrosoft
  Masque les tâches planifiées situées sous \Microsoft\ (tâches système).

.PARAMETER OutputPath
  Dossier du fichier de résultats. Par défaut le dossier du script.

.EXAMPLE
  .\Infos-taches-planifiees.ps1 -ExcludeMicrosoft
#>

[CmdletBinding()]
param(
    [switch]$ExcludeMicrosoft,
    [string]$OutputPath = $PSScriptRoot
)

if (-not $OutputPath) { $OutputPath = (Get-Location).Path }
$null = New-Item -Path $OutputPath -ItemType Directory -Force
$logFile = Join-Path $OutputPath ("Infos-taches-planifiees_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

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

# Etat défini par le Gestionnaire des tâches (onglet Démarrage) : premier octet impair = désactivé
function Get-ApprovedState {
    param([string]$ApprovedKey, [string]$Name)
    $value = $null
    $k = Get-Item -LiteralPath $ApprovedKey -ErrorAction SilentlyContinue
    if ($k) { $value = $k.GetValue($Name) }
    if ($value -is [byte[]] -and $value.Length -gt 0) {
        if ($value[0] % 2 -eq 1) { return 'Désactivé' }
    }
    'Activé'
}

function Get-RunEntries {
    param([string]$Key, [string]$Label, [string]$ApprovedKey)
    $item = Get-ItemProperty -LiteralPath $Key -ErrorAction SilentlyContinue
    if (-not $item) { return }
    $psProps = 'PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider'
    foreach ($p in $item.PSObject.Properties | Where-Object { $psProps -notcontains $_.Name }) {
        [PSCustomObject]@{
            Emplacement = $Label
            Nom         = $p.Name
            Etat        = if ($ApprovedKey) { Get-ApprovedState $ApprovedKey $p.Name } else { 'Activé' }
            Commande    = $p.Value
        }
    }
}

function Get-StartupFolderEntries {
    param([string]$Folder, [string]$Label, [string]$ApprovedKey)
    if (-not $Folder -or -not (Test-Path -LiteralPath $Folder)) { return }
    Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
            [PSCustomObject]@{
                Emplacement = $Label
                Nom         = $_.Name
                Etat        = Get-ApprovedState $ApprovedKey $_.Name
                Commande    = $_.FullName
            }
        }
}

Write-Log '=== Tâches planifiées et programmes au démarrage ===' Cyan
Write-Log "Généré le : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" Gray
Write-Log

Write-Log "--- Tâches planifiées$(if ($ExcludeMicrosoft) { ' (hors \Microsoft\)' }) ---" Cyan
$tasks = Get-ScheduledTask | Where-Object { -not $ExcludeMicrosoft -or $_.TaskPath -notlike '\Microsoft\*' }
$tasks | ForEach-Object {
    $info = $_ | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Chemin        = "$($_.TaskPath)$($_.TaskName)"
        Etat          = $_.State
        DerniereExec  = $info.LastRunTime
        Resultat      = if ($null -ne $info.LastTaskResult) { '0x{0:X}' -f $info.LastTaskResult } else { '' }
        ProchaineExec = $info.NextRunTime
        Action        = ($_.Actions | ForEach-Object { if ($_.Execute) { "$($_.Execute) $($_.Arguments)".Trim() } else { '(COM)' } }) -join ' | '
    }
} | Sort-Object Chemin | Format-Table -AutoSize | Write-Block
Write-Log "Total : $(@($tasks).Count) tâche(s)" Gray

Write-Log
Write-Log '--- Programmes au démarrage ---' Cyan
$hklmApproved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$hkcuApproved = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$startup = @(
    Get-RunEntries 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'HKLM Run' "$hklmApproved\Run"
    Get-RunEntries 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' 'HKLM Run (32 bits)' "$hklmApproved\Run32"
    Get-RunEntries 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' 'HKLM RunOnce' $null
    Get-RunEntries 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'HKCU Run' "$hkcuApproved\Run"
    Get-RunEntries 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' 'HKCU RunOnce' $null
    Get-StartupFolderEntries ([Environment]::GetFolderPath('CommonStartup')) 'Dossier Démarrage (tous)' "$hklmApproved\StartupFolder"
    Get-StartupFolderEntries ([Environment]::GetFolderPath('Startup')) 'Dossier Démarrage (utilisateur)' "$hkcuApproved\StartupFolder"
)
if ($startup) {
    $startup | Format-Table -AutoSize | Write-Block
} else {
    Write-Log 'Aucun programme au démarrage trouvé.' Gray
}

Write-Log
Write-Log "Fichier enregistré : $logFile" Gray
