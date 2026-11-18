# Passation — Havilah SiteCheck, reprise de la phase 1

> Document de reprise du 16/11/2026. À lire en entier avant toute action, avec `CLAUDE.md`, `docs/cdc.md`, les ADR de `docs/adr/` et le plan de phase 1 (`~/.claude/plans/pasted-content-id-955d-lis-claude-md-velvet-storm.md`).
> Le projet a pris environ 3 semaines de retard. L'objectif est d'avancer vite et en autonomie, avec des points de contrôle humains limités aux sujets listés au §4.

## 1. État au 16/11/2026

- Branche de travail : `phase-1` (à créer depuis `main` si elle n'existe pas).
- Étapes 0 et 1 du plan faites : environnement dans `CLAUDE.md`, ADR 0001 à 0008 rédigés.
- ADR **acceptés et commités** : 0001, 0003, 0005, 0006, 0007, 0008.
- ADR **rédigés mais non commités** : 0002 (stockage) et 0004 (révocation). Les décisions ci-dessous les valident ; il reste à les compléter, puis à les committer.
- Aucun code applicatif n'a encore été écrit.

## 2. Décisions prises par le responsable du projet

### ADR 0002 — Stockage objet : accepté, avec deux compléments

- Garage remplace MinIO (édition communautaire archivée en 2026), en développement et pour le pilote. SeaweedFS est l'alternative si Garage échoue au test de compatibilité.
- Le test de compatibilité doit vérifier explicitement qu'un fichier de plus de 400 000 octets envoyé par POST pré-signé est **refusé** (`content-length-range`). Si Garage n'applique pas cette condition, le contrôle de taille au moment de `/confirm` devient la protection principale, et l'ADR doit le dire.
- Mentionner la licence de Garage (AGPL) et ses conséquences pour un usage sans modification.
- Plafond PDF : 10 Mo, désactivé par défaut, configurable.
- Risque à présenter au client : pas de versionnage dans Garage, compensé par une réplication quotidienne vers un second fournisseur.

### ADR 0004 — Révocation des appareils : accepté, avec ces décisions

- L'utilisateur peut révoquer son propre appareil **uniquement en mode immédiat**, avec un libellé du type « Déclarer cet appareil perdu ou volé ».
- La synchronisation finale est réservée à l'administrateur.
- Un changement de téléphone se fait par synchronisation puis déconnexion (EF-OFF-09), sans révocation.
- Délai de synchronisation finale : 7 jours par défaut, configurable. À expiration, les opérations sont refusées et journalisées.
- **Pas d'endpoint sans session** pour le bilan de perte. L'appareil révoqué indique le nombre d'opérations en attente dans sa requête de synchronisation habituelle ; le serveur la refuse, journalise ce nombre et ordonne la purge.
- Les trois ajouts proposés sont conservés : session liée à l'appareil, ordre « révocation puis désactivation du compte », risque d'antidatage en synchronisation finale.
- Lister les amendements du cdc v1.2 (EF-AUT-03, EF-AUT-04, EF-OFF-08, puce « Révocation » du §16.2) dans `docs/cdc-amendements-v1.2.md`, et ajouter l'exception correspondante dans `CLAUDE.md`.

### Dépendances

Validées telles que proposées le 16/11/2026 : Django 5.2 LTS, DRF, drf-spectacular, psycopg 3, Gunicorn, Celery, client Redis, boto3, Pillow, argon2-cffi ; Next.js 16, React 19, TypeScript 6.0, TanStack Query, Dexie, Serwist, openapi-typescript, openapi-fetch, uuid ; outils de test et de lint associés ; Semgrep, Trivy et gitleaks en CI, épinglés ; Garage pour le stockage.

Toute **nouvelle** dépendance hors de cette liste reste soumise à validation (règle de `CLAUDE.md`), mais peut être regroupée avec le prochain point de contrôle du §4 si elle ne bloque pas le travail.

## 3. Mode de travail à partir de maintenant

1. **Autonomie par défaut.** Enchaîne les étapes du plan de phase 1 sans attendre de validation entre chaque étape, sauf aux points de contrôle du §4.
2. **Un commit par étape**, au format Conventional Commits avec les identifiants d'exigences. **`git push` après chaque étape terminée** : rien ne doit rester uniquement en local.
3. Une étape n'est terminée que si le lint et les tests sont verts. Si une étape échoue deux fois de suite sur le même problème, arrête-toi et expose le problème au lieu de contourner.
4. **Journal d'avancement** : tiens `docs/journal-phase-1.md` à jour à la fin de chaque étape (date, étape, commit, ce qui marche, ce qui reste, décisions prises en autonomie). C'est ce fichier que le responsable lira pour suivre le projet.
5. Une décision technique mineure, prise en autonomie, est notée dans le journal. Une décision qui s'écarte du cdc ou d'un ADR fait l'objet d'un nouvel ADR et d'un point de contrôle.
6. Données fictives uniquement. Aucun secret dans le dépôt.

## 4. Points de contrôle humains (tu t'arrêtes et tu attends)

Regroupe les questions pour limiter le nombre d'arrêts. Arrête-toi uniquement :

- **A.** Avant d'écrire le code de l'**authentification, des sessions et de la liaison session–appareil** : présente le design en une page.
- **B.** Avant d'écrire le code des **permissions par objet** (rôle × site) : présente la table des permissions et la stratégie de tests négatifs.
- **C.** Avant d'écrire le **protocole `sync/push`** côté serveur et la file côté client : présente le format des requêtes et réponses, et les cas d'erreur.
- **D.** Avant toute **migration qui supprime ou transforme des données**, et avant tout accès à `IncidentPerson`.
- **E.** Quand le **prototype hors ligne est prêt à être testé sur de vrais téléphones** : fournis la procédure de test pas à pas (`docs/test-appareils.md`) et attends les résultats du responsable.
- **F.** Fin de phase 1 : bilan, écarts au plan, proposition de planning recalé pour les phases suivantes.

Les points A, B et C peuvent être présentés ensemble en un seul arrêt si leur design est prêt en même temps.

## 5. Points ouverts côté client (ne bloquent pas la phase 1)

À traiter par le responsable du projet avec Havilah ; rends tout ce qui en dépend **configurable** :

- répartition Android / iPhone des utilisateurs ;
- acceptation d'un hébergement hors du Gabon pendant la phase VPS ;
- matrice SLA, types d'incident, catégories, modèles d'inspection prioritaires ;
- existence d'un responsable HSE et répartition des rôles de qualification et de vérification ;
- durées de conservation, RPO/RTO ;
- prise en charge des données mobiles des employés.

## 6. Première action attendue

1. Vérifier la branche (`phase-1`) et l'état du dépôt.
2. Compléter et committer les ADR 0002 et 0004 selon le §2, créer `docs/cdc-amendements-v1.2.md`, mettre à jour `CLAUDE.md`, reporter les décisions dans le plan.
3. Créer `docs/journal-phase-1.md`.
4. `git push`.
5. Enchaîner sur l'étape 2 du plan (squelette du monorepo) et les suivantes, jusqu'au premier point de contrôle du §4.
