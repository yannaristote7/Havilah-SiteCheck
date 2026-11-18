# Havilah SiteCheck

Application web mobile (PWA hors ligne) d'inspection terrain, de remontée des anomalies et des incidents, et de suivi des actions correctives, entre la Direction Générale d'Havilah Mining (Libreville) et le site de Tchimbanga (Gabon).

**Source de vérité : `docs/cdc.md`** (cahier des charges v1.1). Avant toute tâche, lis les sections concernées. Cite les identifiants d'exigences (`EF-…`) et de critères d'acceptation (`AC-…`) dans les plans, les commits et les tests.

## État du projet

- Phase en cours : **phase 1 — socle technique et preuve hors ligne** (cdc §20).
- N'implémente pas de fonctionnalité d'une phase ultérieure sans demande explicite.
- Points encore ouverts avec le client : cdc §24.2. Tout ce qui en dépend doit rester **configurable** (matrice SLA, types d'incident, catégories, modèles d'inspection), jamais codé en dur.

## Stack (ne change rien sans ADR validé)

| Couche | Choix |
|---|---|
| Frontend | Next.js + TypeScript strict, **`output: 'export'` (export statique)**, servi par Nginx. Pas de serveur Node.js en production, donc pas de Server Components dynamiques, de routes API Next ni de middleware. |
| Hors ligne | Service Worker (Serwist ou Workbox), IndexedDB via Dexie, TanStack Query |
| Backend | Python, Django LTS, Django REST Framework, drf-spectacular (OpenAPI) |
| Base | PostgreSQL |
| Tâches de fond | Redis + Celery + Celery Beat (**obligatoires**) |
| Fichiers | Stockage objet compatible S3 (Garage en local et pour le pilote, ADR 0002), bucket privé, URL pré-signées |
| Infra | Docker Compose, Nginx, GitHub Actions |

Frontend et API sont servis sur **la même origine** : application à la racine, API sous `/api/v1/`. Il n'y a donc pas de CORS.

## Structure cible du dépôt

```
backend/      projet Django (config/ + apps/ : accounts, sites, templates, inspections,
              anomalies, incidents, actions, sync, notifications, audit)
frontend/     application Next.js (PWA)
infra/        nginx/, docker/, scripts de sauvegarde
docs/         cdc.md, adr/ (décisions d'architecture)
.github/      workflows CI
```

Cette structure peut évoluer, mais par un ADR.

## Règles métier invariantes

- Toute donnée opérationnelle porte un `site_id`. Les querysets passent **toujours** par un filtrage selon les sites autorisés de l'utilisateur. Jamais de `Model.objects.all()` dans une vue.
- Les permissions sont vérifiées **côté serveur, par objet** (rôle × site, cdc §6). Chaque endpoint a des **tests négatifs** : autre site, rôle insuffisant, anonyme.
- Les objets créables hors ligne ont une clé primaire **UUID v7 générée par le client**. La référence lisible (`HSC-ANO-2026-000123`, `HSC-INC-…`, `HSC-ACT-…`) est attribuée par le serveur à la réception.
- Anomalie et incident sont **deux modèles distincts** (cdc §8.1).
- Les changements d'état passent **uniquement** par une fonction de service de transition, exposée par `POST …/{id}/transitions`. Elle valide la transition (état courant, rôle, motif obligatoire) et écrit `StatusHistory` + `AuditEvent` **dans la même transaction**. Ne modifie jamais un champ `status` directement. Codes d'état : cdc §8.6.
- « En retard » et « manquée » sont **calculés**, jamais stockés comme statut.
- `CorrectiveAction` est liée à une anomalie **ou** à un incident : contrainte `CHECK`, exactement un des deux.
- Le vérificateur d'une action ne peut pas en être le responsable.
- Les données `IncidentPerson` (personnes impliquées, blessures) sont à accès restreint et chiffrées au repos. Elles ne doivent jamais apparaître dans les notifications, les logs ni les réponses destinées aux rôles non autorisés, y compris l'administrateur technique.
- Pas de suppression des données opérationnelles : archivage logique.
- Dates stockées en UTC, calculs d'échéance et affichage dans le fuseau `Africa/Libreville`.

## Hors ligne (le risque n°1 du projet)

- Les fonctions marquées « Oui » dans la matrice hors ligne (cdc §7.11) doivent fonctionner **sans réseau pendant 96 h**.
- Toute écriture terrain passe par la file d'opérations IndexedDB. Chaque opération porte un **`Idempotency-Key`** et est envoyée par lot à `POST /api/v1/sync/push`. Rejouer un lot ne doit créer aucun doublon.
- Ne compte **pas** sur la Background Sync API, qui ne fonctionne pas sur iOS. La synchronisation se déclenche à l'ouverture, à l'événement `online` et périodiquement tant que l'application est ouverte.
- Photos : redimensionnement à 1 600 px maximum sur le côté le plus long, ré-encodage par canvas (ce qui **supprime l'EXIF et donc le GPS**), cible de 150 à 350 Ko. Téléversement par URL pré-signée **avant** de référencer la pièce jointe.
- **Ne supprime jamais automatiquement une donnée non synchronisée.** Seule exception : l'ordre de purge d'une révocation immédiate de l'appareil (ou d'une synchronisation finale expirée), journalisé côté serveur (ADR 0004, EF-AUT-04 amendé).
- Conflits : jamais d'écrasement silencieux. Une transition refusée par le serveur part dans la liste « À résoudre ».
- Une fonctionnalité hors ligne n'est terminée qu'après un test sur un vrai téléphone Android **et** un vrai iPhone (application installée sur l'écran d'accueil).

## Sécurité

- Aucun secret dans le dépôt : seulement un `.env.example`. Aucune donnée de production dans les prompts ni dans les fixtures ; utilise des données fictives.
- Authentification par session Django, cookie `httpOnly`, `Secure`, `SameSite`, protection CSRF active. Pas de jeton stocké dans `localStorage` ni dans IndexedDB.
- Fichiers : bucket privé, noms générés côté serveur, vérification du type réel et de la taille, URL de téléchargement valables 15 min au plus.
- Logs structurés, sans données personnelles ni secrets.
- **Demande avant d'ajouter une dépendance.** Indique pourquoi elle est nécessaire et si elle est maintenue.

## Zones sensibles : explique d'abord, attends ma validation

Authentification et sessions, permissions, protocole de synchronisation, migrations qui suppriment ou transforment des données, `IncidentPerson`, accès au stockage de fichiers. Pour ces sujets, présente le changement et ses risques **avant** de coder.

## Conventions de code

- Identifiants, code et noms de tables en **anglais**. Interface utilisateur en **français**, avec des libellés externalisés. Documentation en français.
- Backend : ruff (lint + format), pytest + pytest-django + factory_boy.
- Frontend : ESLint, Prettier, Vitest, Playwright, y compris des scénarios hors ligne simulés.
- Le **client API TypeScript est généré** depuis le schéma OpenAPI (openapi-typescript). N'écris jamais les types d'API à la main.
- Les tests citent l'exigence couverte, par exemple `test_ef_off_04_replayed_batch_creates_no_duplicate`.
- Couverture d'au moins 80 % sur la logique métier : services, transitions, permissions.

## Commandes

À compléter pendant la phase 1. Garde cette section à jour dès qu'une commande change.

```bash
# docker compose up -d                       # démarre toute la stack
# docker compose exec backend pytest         # tests backend
# docker compose exec backend python manage.py spectacular --file schema.yml
# cd frontend && npm run lint && npm test    # tests frontend
```

## Méthode de travail

1. Pour toute tâche non triviale : **plan d'abord**, avec les fichiers touchés, les exigences couvertes et les risques. Attends ma validation avant de coder.
2. Si le cdc est ambigu, incomplet ou contradictoire : **pose la question, ne devine pas**.
3. Petits commits au format Conventional Commits (`feat:`, `fix:`, `test:`…) avec une description en français et les identifiants d'exigences, par exemple `feat(sync): lot idempotent (EF-OFF-04)`.
4. Toute décision technique non prévue par le cdc, ou qui s'en écarte, fait l'objet d'un ADR dans `docs/adr/NNNN-titre.md` (contexte, décision, alternatives, conséquences).
5. Avant de déclarer une tâche terminée : lint et tests verts, schéma OpenAPI régénéré, et ce fichier mis à jour si nécessaire.

## Environnement de développement

- Poste Windows 11 + WSL2 (Ubuntu), dépôt cloné dans le système de fichiers Linux (~/projets/havilah-sitecheck).
- Docker Desktop avec intégration WSL2 ; toutes les commandes se lancent depuis le terminal Ubuntu.
- Laragon est installé côté Windows et peut occuper les ports 80/443/3306 : en local, exposer Nginx sur 8080 et ne pas publier PostgreSQL sur 3306 ni 5432 côté hôte sans nécessité.
- Fins de ligne LF imposées par `.gitattributes`.
