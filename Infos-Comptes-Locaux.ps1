<#
.SYNOPSIS
  Liste et donne l'état des comptes locaux (activé, membre du groupe Administrateurs).
#>

$users = Get-LocalUser
$report = foreach ($u in $users) {
    $isAdmin = $null -ne (Get-LocalGroupMember -Group "Administrateurs" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $u.Name })
    [PSCustomObject]@{
        Name = $u.Name
        Enabled = $u.Enabled
        LastLogon = $u.LastLogon
        Description = $u.Description
        IsAdmin = $isAdmin
    }
}
$report | Format-Table -AutoSize
