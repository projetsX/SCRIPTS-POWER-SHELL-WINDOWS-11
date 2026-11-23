### Windows 11 Scripts PowerShell

Collection de scripts d'administration PowerShell pour Windows 11.

Compatibles Windows PowerShell 5.1 (inclus dans Windows 11) et PowerShell 7.
Les fichiers sont encodés en UTF-8 avec BOM : conserver cet encodage pour que les accents s'affichent correctement sous PowerShell 5.1.

Aide détaillée de chaque script : `Get-Help .\NomDuScript.ps1 -Full`

Si l'exécution est bloquée : `powershell -ExecutionPolicy Bypass -File .\NomDuScript.ps1` ou `Unblock-File .\NomDuScript.ps1`.

Les scripts produisant un fichier acceptent `-OutputPath` (dossier de sortie, par défaut le dossier du script). Les fichiers générés sont exclus de git (`.gitignore`).

Historique des modifications : [CHANGELOG.md](CHANGELOG.md)
## Scripts

### Diagnostics & Monitoring

**`diagnostiques-reseaux.ps1`**  
Teste la connectivité réseau : adaptateurs, adresses IPv4, passerelles (ping), serveurs DNS, résolution DNS chronométrée, ping ou test TCP vers l'hôte cible, traceroute. Résultats en console + fichier .txt horodaté.  
Param : `-HostToTest` (défaut 8.8.8.8), `-Port` (test TCP au lieu du ping), `-DnsName` (défaut www.microsoft.com), `-SkipTraceroute`

**`Infos-sante-disque-v2.ps1`**  
Espace des volumes (alerte au-delà de `-WarnPercent`, défaut 90 %), état des disques physiques, compteurs de fiabilité (température, usure SSD, heures de fonctionnement, erreurs non corrigées, compatible NVMe) et prédiction de panne SMART. Console + .txt horodaté.  
Admin requis pour les compteurs de fiabilité et SMART.

**`Infos-Systeme.ps1`**  
Résumé matériel/logiciel : OS (version 2xH2, build), uptime, CPU, barrettes mémoire, GPU, BIOS, Secure Boot, TPM, BitLocker, disques, cartes réseau et versions de pilotes, applications installées (machine + utilisateur). Console + .txt horodaté.  
Param : `-SkipApps`. Admin recommandé (TPM, Secure Boot, BitLocker).

**`Infos-topProcess.ps1`**  
Affiche les processus les plus consommateurs : charge CPU instantanée (%), temps CPU cumulé, mémoire de travail et privée.  
Param : `-Top` (défaut 20), `-SortBy` CPU|Memory, `-SampleSeconds` (défaut 1)

**`Infos-taches-planifiees.ps1`**  
Liste les tâches planifiées (état, dernière/prochaine exécution, code résultat, action) et les programmes au démarrage (Run/RunOnce HKLM/HKCU, 32 bits, dossiers Démarrage) avec leur état activé/désactivé dans le Gestionnaire des tâches. Console + .txt horodaté.  
Param : `-ExcludeMicrosoft` (masque les tâches système \Microsoft\)

**`Infos-Comptes-Locaux.ps1`**  
Liste les comptes locaux : état, membre Administrateurs (détecté par SID, indépendant de la langue), dernière connexion, date du mot de passe, description. Affiche aussi tous les membres du groupe Administrateurs (comptes Microsoft/Entra ID inclus).

### Services & Network

**`service-check-restart.ps1`**  
Vérifie l'état d'un service (type de démarrage, dépendants) et propose de le redémarrer, ou de le démarrer s'il est arrêté. Caractères génériques refusés.  
Param : `-ServiceName` (obligatoire, nom court ou nom complet), `-Force` (sans confirmation), `-TimeoutSeconds` (défaut 30), `-WhatIf`

**`Reset-Reseau-Windows11.ps1`**  
Réinitialise le réseau : caches DNS/ARP/NetBIOS, Winsock, pile TCP/IP v4/v6, services DHCP et Connexions réseau, cartes réseau physiques, bail DHCP, réenregistrement DNS. Sauvegarde `ipconfig /all` avant modification. Log détaillé horodaté, bilan des erreurs, code de sortie 1 en cas d'erreur.  
Param : `-Force` (sans confirmation), `-FlushRoutes` (vide aussi la table de routage, déconseillé avec une IP statique), `-NoRestartPrompt`  
Admin requis. Redémarrage nécessaire pour finaliser.

**`Test-Mails-Ports.ps1`**  
Teste la connectivité TCP vers un serveur mail avec délai maximal par port : SMTP (25, 465, 587), IMAP (143, 993), POP3 (110, 995). Distingue OUVERT / FERMÉ (refusé) / FILTRÉ (délai dépassé) et affiche la bannière du serveur sur les ports en clair.  
Param : `-MailServer` (obligatoire, ex : smtp.gmail.com), `-TimeoutMs` (défaut 3000)  
Code de sortie : 0 si au moins un port ouvert, 1 sinon, 2 si le nom ne se résout pas.

### Exports & Reports

**`export-logs.ps1`**  
Exporte les journaux Windows des N derniers jours en .evtx, compressés dans une archive .zip horodatée.  
Param : `-Days` (défaut 7), `-LogName` (défaut Application, System, Security ; accepte les journaux détaillés), `-KeepFolder` (conserve les .evtx non compressés)  
Admin requis pour le journal Security.

**`Firewall-rapport.ps1`**  
Exporte les règles du pare-feu (stratégie active) en JSON et CSV (séparateur régional, ouverture directe dans Excel) avec protocole, ports, adresses distantes et programme. Affiche un résumé des règles entrantes autorisées et des règles de blocage.  
Param : `-OutputPath` (défaut %TEMP%), `-EnabledOnly`, `-BlockedOnly` (uniquement les règles de blocage, affichées en console)