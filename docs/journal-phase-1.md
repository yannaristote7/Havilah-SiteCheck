# Journal de la phase 1

Suivi d'avancement de la phase 1 (cdc §20), mis à jour à la fin de chaque étape du plan. Les décisions prises en autonomie sont notées ici ; celles qui s'écartent du cdc ou d'un ADR font l'objet d'un ADR.

## État des étapes

| Étape | Intitulé | État | Commit |
|---|---|---|---|
| 0 | Environnement de développement dans CLAUDE.md | Fait | `4045c46` |
| 1 | ADR de la phase 1 (0001 à 0008) | Fait, tous acceptés | `581ee28` … `636e95b` |
| 2 | Squelette du monorepo | Fait | voir entrée |
| 3 | Projet Django et API de base | À faire | |
| 4 | Application Next.js en export statique | À faire | |
| 5 | Intégration continue | À faire | |
| 6 | Stack Docker Compose | À faire | |
| 7 | Comptes, sites, rôles, appareils | À faire | |
| 8 | Journal d'audit | À faire | |
| 9 | 🔒 Authentification (point de contrôle A) | À faire | |
| 10 | 🔒 Permissions (point de contrôle B) | À faire | |
| 11 | 🔒 Pièces jointes | À faire | |
| 12 | 🔒 Synchronisation (point de contrôle C) | À faire | |
| 13 | PWA, Service Worker, fenêtre 96 h | À faire | |
| 14 | Saisie hors ligne et moteur de synchronisation | À faire | |
| 15 | Scénarios e2e hors ligne | À faire | |
| 16 | README et protocole de test sur appareils (point de contrôle E) | À faire | |
| 17 | Préproduction sur VPS | À faire | |

## Entrées

### 2026-11-16 / 18 — Étape 1 terminée : ADR acceptés

- ADR 0001, 0003, 0005, 0006, 0007, 0008 acceptés et commités le 2026-11-16.
- ADR 0002 (stockage : Garage, étapes A/B, plafonds configurables) et 0004 (révocation en deux modes) complétés selon la passation du 2026-11-16 et commités.
- Amendements du cdc v1.2 consignés dans `docs/cdc-amendements-v1.2.md`. Exception de purge ajoutée dans `CLAUDE.md`.
- Dépendances validées le 2026-11-16 (voir passation §2).

**Décisions prises en autonomie**

- La passation (`docs/passation-claude-code.md`) est versionnée avec les autres documents, pour que rien ne reste en local.

**Blocage d'environnement**

- L'utilisateur WSL n'appartient pas au groupe `docker` : `docker` renvoie « permission denied » sur `/var/run/docker.sock`. Node n'est pas installé dans WSL et Python y est en 3.10. Tous les outils (uv, Python 3.13, Node 24) tourneront dans des conteneurs, mais il faut d'abord rétablir l'accès à Docker (voir la commande dans le README une fois écrit, ou `sudo usermod -aG docker $USER` puis `wsl --shutdown`).

### 2026-11-18 — Étape 2 terminée : squelette du monorepo

- `.editorconfig`, `.gitignore`, `.env.example` (valeurs fictives), `Makefile` (raccourcis Docker Compose), README de démarrage, dossiers `infra/`.
- Pas de code, donc ni lint ni tests à cette étape.

**Décisions prises en autonomie**

- Plafonds de pièces jointes exprimés dans une seule variable `ATTACHMENT_TYPES` au format `type:plafond:actif` (ADR 0002).
- `S3_PUBLIC_ENDPOINT` vaut l'origine de l'application (`http://localhost:8080`) : le bucket est servi sous `/hsc-files/` sans réécriture.
- Le Makefile lance le frontend par `docker compose run --rm frontend` : aucun Node local nécessaire.

**Reste à faire** : étape 3, qui exige l'accès à Docker (voir le blocage ci-dessus).
