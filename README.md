### Windows 11 Scripts PowerShell

Collection de scripts d'administration PowerShell pour Windows 11.

## Scripts

### Diagnostics & Monitoring

**`diagnostiques-reseaux.ps1`**  
Teste connectivité réseau : adaptateurs, résolution DNS, routes, traceroute. Résultats en console + fichier .txt horodaté.  
Param: `-HostToTest` (défaut 8.8.8.8)

**`Infos-sante-disque-v2.ps1`**  
Récupère état SMART et espace disque. Affichage console + export .txt horodaté.  
Admin requis pour données SMART complètes.

**`Infos-Systeme.ps1`**  
Résumé hardware/logiciel : OS, CPU, RAM, firmware, drivers réseau. Export .txt horodaté.

**`Infos-topProcess.ps1`**  
Affiche top 20 processus triés par consommation CPU. Inclut ID, nom, CPU, mémoire (MB).

**`Infos-taches-planifiees.ps1`**  
Liste tâches planifiées (Task Scheduler) + clés Run au démarrage (HKLM/HKCU). Export console + .txt horodaté.

**`Infos-Comptes-Locaux.ps1`**  
Liste comptes locaux : état (activé/désactivé), membre Administrateurs, dernière connexion, description.

### Services & Network

**`service-check-restart.ps1`**  
Vérifie état service donné et propose redémarrage (ou force si `-Force`).  
Param: `-ServiceName` (obligatoire), `-Force` (optionnel)

**`Reset-Reseau-Windows11.ps1`**  
Réinitialise réseau : DNS, cache, cartes réseau, pile TCP/IP. Log détaillé horodaté.  
Admin requis.

**`Test-Mails-Ports.ps1`**  
Teste connectivité TCP vers serveur mail : SMTP (25, 465, 587), IMAP (143, 993).  
Param: `-MailServer` (obligatoire, ex: smtp.gmail.com)

### Exports & Reports

**`export-logs.ps1`**  
Exporte journaux Windows (Application, System, Security) des N derniers jours en .evtx.  
Param: `-Days` (défaut 7). Admin requis pour journaux sécurité.

**`Firewall-rapport.ps1`**  
Exporte règles firewall actives en JSON et CSV dans %TEMP%.