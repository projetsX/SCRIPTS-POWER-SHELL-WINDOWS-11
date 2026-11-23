<#
.SYNOPSIS
  Liste les comptes locaux et leur état (activé, membre du groupe Administrateurs, dernière connexion).

.DESCRIPTION
  Le groupe Administrateurs est identifié par son SID (S-1-5-32-544), ce qui fonctionne
  quelle que soit la langue de Windows. Les membres non locaux (compte Microsoft/Entra ID,
  domaine) du groupe sont également listés.
#>

[CmdletBinding()]
param()

$adminSid = 'S-1-5-32-544'
$adminGroup = Get-LocalGroup -SID $adminSid

# Get-LocalGroupMember échoue si le groupe contient des SID orphelins (cas fréquent avec Entra ID) : repli via ADSI
try {
    $members = @(Get-LocalGroupMember -SID $adminSid -ErrorAction Stop |
        Select-Object Name, @{ Name = 'SID'; Expression = { $_.SID.Value } }, ObjectClass, PrincipalSource)
} catch {
    $members = @(([ADSI]"WinNT://$env:COMPUTERNAME/$($adminGroup.Name),group").psbase.Invoke('Members') | ForEach-Object {
            $sidBytes = $_.GetType().InvokeMember('objectSid', 'GetProperty', $null, $_, $null)
            $sid = New-Object Security.Principal.SecurityIdentifier($sidBytes, 0)
            $name = try { $sid.Translate([Security.Principal.NTAccount]).Value } catch { '(SID orphelin)' }
            [PSCustomObject]@{ Name = $name; SID = $sid.Value; ObjectClass = ''; PrincipalSource = '' }
        })
}
$adminSids = $members.SID

$report = Get-LocalUser | Sort-Object Name | ForEach-Object {
    [PSCustomObject]@{
        Nom               = $_.Name
        Active            = $_.Enabled
        Admin             = $adminSids -contains $_.SID.Value
        DerniereConnexion = if ($_.LastLogon) { $_.LastLogon } else { 'Jamais' }
        MdpModifie        = $_.PasswordLastSet
        MdpRequis         = $_.PasswordRequired
        Description       = $_.Description
    }
}

Write-Host '=== Comptes locaux ===' -ForegroundColor Cyan
$report | Format-Table -AutoSize -Wrap | Out-Host

Write-Host "=== Membres du groupe $($adminGroup.Name) ===" -ForegroundColor Cyan
$members | Sort-Object Name | Format-Table -AutoSize | Out-Host
