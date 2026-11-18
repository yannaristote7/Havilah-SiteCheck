# 0004 — Appareils, deux modes de révocation et fenêtre hors ligne

- **Date** : 2026-10-27, révisée le 2026-11-16
- **Statut** : acceptée (2026-11-16)
- **Exigences concernées** : EF-AUT-03, EF-AUT-04, EF-OFF-08, EF-OFF-09, EF-OFF-10, §16.2 du cdc

## Contexte

EF-AUT-04 demande qu'un appareil révoqué voie « ses données locales purgées au prochain contact ». EF-AUT-03 et EF-OFF-08 interdisent toute suppression automatique de données non synchronisées. Les deux exigences sont contradictoires pour les données en attente.

Une révocation correspond à deux situations différentes :

- **Départ d'un employé** : l'appareil est entre de bonnes mains. Les saisies en attente sont du travail légitime qu'il faut récupérer.
- **Perte, vol, compromission** : l'appareil peut être entre de mauvaises mains. Rien de ce qu'il envoie n'est fiable, et ses données locales doivent disparaître dès que possible.

Un **changement de téléphone** n'est pas une révocation : l'utilisateur synchronise, puis se déconnecte (EF-OFF-09), ce qui purge l'appareil après une synchronisation complète.

La première version de cet ADR (purge partielle, file verrouillée sur l'appareil) ne traitait correctement aucun des deux cas : les saisies légitimes restaient bloquées, et les données d'un téléphone volé restaient lisibles.

## Décision

### 1. Enregistrement de l'appareil

Le client génère un **`device_id`** (UUID v7) au premier lancement et le conserve dans IndexedDB. Ce n'est pas un jeton d'authentification. Il est envoyé à la connexion et dans l'en-tête `X-Device-Id` de chaque requête de l'API. Le serveur crée ou met à jour l'objet `Device` (utilisateur, libellé, navigateur, dernière synchronisation) et **lie la session à cet appareil** : une requête dont l'en-tête `X-Device-Id` ne correspond pas à l'appareil de la session est refusée.

### 2. Deux modes de révocation

Chaque révocation enregistre l'heure (`revoked_at`), le mode, le motif et l'auteur, et est **journalisée dans l'audit**.

| | **Révocation avec synchronisation finale** | **Révocation immédiate** |
|---|---|---|
| Cas d'usage | Départ d'un employé | Perte, vol, compromission |
| Qui peut la déclencher | **Administrateur uniquement** | Administrateur, **ou l'utilisateur pour ses propres appareils** (« Déclarer cet appareil perdu ou volé ») |
| Sessions de l'appareil | Conservées, mais limitées à la synchronisation finale | Supprimées immédiatement |
| Au prochain contact | Le serveur accepte les opérations créées **avant** `revoked_at`, puis ordonne la purge complète | Le serveur refuse la synchronisation et ordonne la purge complète, **y compris les données non synchronisées** |
| Données en attente | Récupérées (sauf celles créées après la révocation) | **Perdues** ; leur nombre est journalisé |

**Révocation avec synchronisation finale** :

1. Toute requête de l'appareil reçoit **403 `device_revoked`** avec `mode: final_sync` et `revoked_at`, sauf `POST /sync/push` et les requêtes de pièces jointes (presign, confirm) liées à ces opérations.
2. Le client arrête toute nouvelle saisie et envoie sa file.
3. Le serveur accepte les opérations dont `client_created_at` est antérieur à `revoked_at`, avec les règles habituelles (idempotence, dépendances, permissions). Celles créées après sont refusées (`created_after_revocation`).
4. Quand sa file est vide, le client appelle `POST /devices/current/final-sync-complete` (avec sa session). Le serveur journalise le bilan (opérations acceptées, refusées, et nombre d'éléments `FAILED` ou `CONFLICT` non résolus, qui seront perdus), supprime les sessions et répond `purge`.
5. Le client **purge tout** : données, file, référentiels, puis revient à l'écran de connexion.
6. Si le contact est interrompu, la reprise est sans risque grâce à l'idempotence de la synchronisation (ADR 0003).
7. **Délai de synchronisation finale** : 7 jours par défaut, configurable (`DEVICE_FINAL_SYNC_DAYS`). À expiration, les sessions sont supprimées. Au contact suivant, les opérations sont **refusées** (`final_sync_expired`), leur nombre est **journalisé** et l'appareil reçoit l'ordre de purge, comme en mode immédiat.

**Révocation immédiate** :

1. Les sessions sont supprimées.
2. Le client ne sait pas encore qu'il est révoqué : à son prochain contact, il envoie sa requête de synchronisation habituelle. Chaque `POST /sync/push` porte l'en-tête **`X-Pending-Count`** (nombre d'opérations en attente sur l'appareil), révoqué ou non.
3. Le serveur identifie l'appareil révoqué par son `X-Device-Id`, **refuse** la requête par **403 `device_revoked`** avec `mode: immediate`, **journalise** le nombre d'opérations en attente déclaré par l'appareil, puis ordonne la purge. Il n'existe **aucun endpoint dédié sans session** ; le nombre n'est journalisé qu'au premier contact après la révocation, et il est marqué comme « déclaré par l'appareil ».
4. Le client purge immédiatement tout son contenu local, **y compris la file non synchronisée**, puis revient à l'écran de connexion.

### 3. Ordre des opérations pour un départ

L'interface d'administration impose l'ordre suivant : révocation avec synchronisation finale, attente du bilan ou de l'expiration du délai, **puis** désactivation du compte et des appartenances. Sinon, les opérations finales seraient refusées faute de droits sur le site.

### 4. Fenêtre hors ligne de 96 h

Le client enregistre `last_online_auth_at` après chaque `GET /auth/me` réussi. Au-delà de 96 h, toute nouvelle saisie est bloquée jusqu'à une reconnexion. La file est conservée et reste consultable.

## Alternatives étudiées

- **Purge partielle (première version de cet ADR)** : file verrouillée sur l'appareil, ni récupérée ni effacée. Mauvais dans les deux cas. Remplacée.
- **Un seul mode, avec synchronisation finale** : un téléphone volé pourrait envoyer de fausses saisies au nom de l'employé. Écartée.
- **Un seul mode, immédiat (lecture littérale d'EF-AUT-04)** : perte du travail d'un employé qui quitte l'entreprise. Écartée.
- **Synchronisation finale déclenchable par l'utilisateur** : il pourrait l'utiliser pour un appareil perdu par erreur de choix. Écartée : l'utilisateur n'a accès qu'au mode immédiat.
- **Endpoint de bilan de perte sans session** : surface d'attaque supplémentaire pour un bénéfice informatif. Écartée au profit de l'en-tête `X-Pending-Count` sur la requête de synchronisation habituelle.

## Conséquences

### Risques résiduels, à expliquer au client

- **Antidatage** : `client_created_at` vient de l'appareil, qui peut changer son horloge. En synchronisation finale, quelqu'un qui détient le téléphone pourrait antidater une saisie. C'est pourquoi ce mode est réservé à l'administrateur, pour les appareils entre de bonnes mains. Les opérations reçues ainsi sont marquées « synchronisation finale » dans l'audit, pour relecture par le responsable du site.
- **Téléphone qui ne se reconnecte jamais** : aucune purge n'est possible à distance (déjà indiqué au §16.2). Le verrouillage de l'écran exigé par la charte BYOD reste la principale protection.
- **Révocation immédiate** : les saisies non synchronisées sont définitivement perdues. L'administrateur et l'utilisateur en sont avertis au moment de la confirmation.
- **Nombre d'opérations perdues** : il est déclaré par l'appareil, donc non vérifiable. Le `device_id` n'étant pas secret, un tiers qui le connaît pourrait fausser ce nombre une fois ; l'impact se limite au journal.
- La fenêtre de 96 h repose sur l'horloge de l'appareil ; la session serveur de 7 jours reste l'autorité.

### Documents à mettre à jour

- Amendements du cdc v1.2 (EF-AUT-03, EF-AUT-04, EF-OFF-08, puce « Révocation » du §16.2) : `docs/cdc-amendements-v1.2.md`.
- `CLAUDE.md` : exception à la règle « Ne supprime jamais automatiquement une donnée non synchronisée ».
