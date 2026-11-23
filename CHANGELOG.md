# Changelog

Toutes les modifications notables de ce projet sont consignées dans ce fichier.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [2026-11-23]

### Général

- Fichiers `.ps1` réencodés en UTF-8 avec BOM : les accents s'affichent désormais correctement sous Windows PowerShell 5.1 (version par défaut de Windows 11).
- Compatibilité Windows PowerShell 5.1 et PowerShell 7 ; `Get-WmiObject` (absent de PowerShell 7) remplacé par `Get-CimInstance`.
- Ajout de `[CmdletBinding()]`, de paramètres validés et d'une aide complète (`Get-Help .\script.ps1 -Full`) sur tous les scripts.
- Paramètre `-OutputPath` sur tous les scripts produisant des fichiers.
- Les tableaux ne sont plus tronqués dans les fichiers texte générés.
- Ajout d'un `.gitignore` excluant les rapports et journaux générés.
- README mis à jour (paramètres, prérequis, exécution).

### diagnostiques-reseaux.ps1

- Corrigé : le test de résolution DNS annoncé dans le README n'existait pas ; ajout d'une résolution chronométrée (`-DnsName`).
- Ajouté : test de joignabilité des passerelles par défaut.
- Ajouté : test TCP vers un port (`-Port`) en alternative au ping.
- Ajouté : option `-SkipTraceroute` ; traceroute plus rapide (sans résolution de noms).
- Ajouté : validation du nom d'hôte saisi.

### export-logs.ps1

- Corrigé : filtre de date XPath fragile remplacé par `timediff()`.
- Corrigé : les échecs de `wevtutil` sont désormais détectés (code de sortie) et le message d'erreur affiché.
- Modifié : l'admin n'est exigé que si le journal Security est demandé.
- Modifié : le dossier des `.evtx` est supprimé après compression (option `-KeepFolder` pour le conserver).
- Ajouté : paramètre `-LogName` acceptant aussi les journaux détaillés (ex : `Microsoft-Windows-PowerShell/Operational`) ; journaux inexistants signalés.

### Firewall-rapport.ps1

- Corrigé : le JSON contenait des valeurs numériques au lieu de libellés lisibles.
- Corrigé : le CSV perdait les accents ; il utilise maintenant le séparateur régional (ouverture directe dans Excel).
- Ajouté : protocole, ports locaux/distants, adresses distantes et programme de chaque règle (récupération groupée des filtres).
- Ajouté : option `-EnabledOnly` et résumé des règles entrantes autorisées.
- Ajouté : option `-BlockedOnly` : n'exporte que les règles de blocage et les affiche en console (sens, protocole, ports, adresses distantes, profil, programme) ; dossier d'export suffixé `_Bloques`. Combinable avec `-EnabledOnly`.
- Ajouté : nombre de règles de blocage activées dans le résumé standard.

### Infos-Comptes-Locaux.ps1

- Corrigé : nom du groupe « Administrateurs » codé en dur (échec sur un Windows non français) ; le groupe est identifié par son SID `S-1-5-32-544`.
- Corrigé : comparaison par expression régulière provoquant des faux positifs ; comparaison exacte par SID.
- Corrigé : repli ADSI si `Get-LocalGroupMember` échoue (SID orphelins, Entra ID).
- Ajouté : date du mot de passe, mot de passe requis, liste complète des membres du groupe Administrateurs.

### Infos-sante-disque-v2.ps1

- Ajouté : compteurs de fiabilité (température, usure SSD, heures de fonctionnement, erreurs non corrigées), compatibles NVMe.
- Ajouté : état des disques physiques avec alerte si non sain.
- Ajouté : alerte de remplissage des volumes (`-WarnPercent`, défaut 90 %).
- Modifié : prédiction SMART via `Get-CimInstance` ; message adapté lorsque SMART n'est pas disponible (NVMe, RAID).

### Infos-Systeme.ps1

- Ajouté : version de Windows (ex : 26H2), build complet, uptime, domaine/groupe de travail.
- Ajouté : barrettes mémoire, carte(s) graphique(s), Secure Boot, TPM, BitLocker, versions de pilotes réseau.
- Ajouté : applications installées pour l'utilisateur courant (HKCU), sans doublons ni composants système ; option `-SkipApps`.
- Modifié : affichage en console en plus du fichier.
- Modifié : fichier renommé `system_overview_*.txt` -> `Infos-Systeme_*.txt`.

### Infos-taches-planifiees.ps1

- Ajouté : dernière/prochaine exécution, code résultat et action de chaque tâche ; option `-ExcludeMicrosoft`.
- Ajouté : clés RunOnce, clé Run 32 bits et dossiers Démarrage.
- Ajouté : état activé/désactivé des programmes au démarrage tel que défini dans le Gestionnaire des tâches.
- Corrigé : affichage illisible des clés Run (propriétés PowerShell internes listées).

### Infos-topProcess.ps1

- Corrigé : le tri utilisait le temps CPU cumulé et non la charge actuelle ; ajout de la charge CPU instantanée en %.
- Ajouté : mémoire privée, paramètres `-Top`, `-SortBy` (CPU / Memory) et `-SampleSeconds`.

### Reset-Reseau-Windows11.ps1

- Corrigé : les étapes en échec étaient signalées comme réussies (code de sortie des commandes natives ignoré).
- Corrigé : la sortie d'`ipconfig` s'affichait sur une seule ligne.
- Corrigé : redémarrage de `Dnscache` (refusé par Windows 11) remplacé par `ipconfig /registerdns`.
- Corrigé : les fichiers `reset.log` de netsh étaient créés dans le dossier courant ; ils vont désormais dans `-OutputPath`.
- Modifié : la table de routage n'est plus vidée par défaut (option `-FlushRoutes`), car cela supprime la passerelle et coupe la connexion en IP statique.
- Ajouté : sauvegarde d'`ipconfig /all` avant toute modification.
- Ajouté : redémarrage des cartes réseau physiques actives.
- Ajouté : bilan des erreurs/avertissements et code de sortie 1 en cas d'erreur.
- Ajouté : options `-Force` (sans confirmation) et `-NoRestartPrompt`.

### service-check-restart.ps1

- Corrigé : un nom contenant des caractères génériques (ex : `w*`) pouvait redémarrer plusieurs services ; ils sont désormais refusés.
- Ajouté : démarrage du service s'il est arrêté (au lieu d'un redémarrage), attente de l'état final (`-TimeoutSeconds`).
- Ajouté : recherche par nom complet, affichage du type de démarrage et des services dépendants, refus si le service est désactivé.
- Ajouté : prise en charge de `-WhatIf`.

### Test-Mails-Ports.ps1

- Corrigé : les ports 110 et 995 étaient étiquetés IMAP au lieu de POP3.
- Corrigé : environ 20 s d'attente par port bloqué ; délai maximal configurable (`-TimeoutMs`, défaut 3000).
- Ajouté : distinction OUVERT / FERMÉ (refusé) / FILTRÉ (délai dépassé).
- Ajouté : affichage de la bannière du serveur sur les ports en clair (caractères de contrôle filtrés).
- Ajouté : vérification préalable de la résolution DNS (code de sortie 2 en cas d'échec).

## [2026-06-11]

- README : description détaillée des scripts.

## [2026-06-08]

- Version initiale : scripts de diagnostic réseau, santé disque, infos système, processus, tâches planifiées, comptes locaux, gestion de service, réinitialisation réseau, test des ports mail, export des journaux et rapport pare-feu.
- Ajout du README.
