# 0003 — Protocole de synchronisation v1

- **Date** : 2026-10-27
- **Statut** : proposée
- **Exigences concernées** : EF-OFF-03, EF-OFF-04, EF-OFF-05, EF-OFF-06, EF-OFF-07, AC-05, AC-06, §8.6, §15 du cdc

## Contexte

Toute écriture terrain passe par une file d'opérations IndexedDB envoyée par lots à `POST /api/v1/sync/push`. Rejouer un lot ne doit créer aucun doublon. iOS suspend la page en arrière-plan : un lot peut être interrompu à tout moment. Le cdc ne définit pas la différence entre les états `LOCAL` et `PENDING`.

## Décision

**Requête** : `POST /api/v1/sync/push`, en-têtes `Idempotency-Key` (identifiant du lot), `X-Device-Id` et `X-CSRFToken`.

```json
{ "operations": [
  { "op_id": "<uuid v7>", "type": "probe_note.create", "entity_id": "<uuid v7>",
    "payload": { "...": "..." }, "client_created_at": "2026-10-27T08:15:00Z" }
] }
```

- 100 opérations au plus par lot. L'`op_id` est la clé d'idempotence de l'opération.
- Chaque opération est traitée dans **sa propre transaction**. Le serveur enregistre une `SyncOperation` (op_id unique, appareil, utilisateur, type, empreinte SHA-256 du payload canonique, statut, résultat).

**Réponse** : HTTP 200 avec un résultat par opération :

| Statut | Sens | Action du client |
|---|---|---|
| `applied` | Opération appliquée. | Passe l'élément en `SYNCED`, enregistre `server_ref`. |
| `duplicate` | `op_id` déjà reçu avec le même payload ; le résultat stocké est renvoyé. | Identique à `applied`. |
| `retry` | Condition temporaire (pièce jointe non confirmée, verrou…). | Garde l'opération, nouvelle tentative avec backoff. |
| `rejected` | Refus définitif (validation, site non autorisé, `idempotency_mismatch`). | Passe l'élément en `FAILED`, affiché dans « À résoudre ». |
| `conflict` | Transition invalide car l'état serveur a changé (phase 4). | Passe l'élément en `CONFLICT`, liste « À résoudre ». |

Erreurs de lot : 401 (session absente), 403 `device_revoked`, 413 (lot trop gros), 429 (limitation) au format `application/problem+json`.

**Ordre pour un élément avec photo** : presign → POST vers le stockage → confirm → opération qui référence la pièce jointe.

**États côté appareil** (décision du 2026-10-27) :

| Code | Libellé | Définition |
|---|---|---|
| `LOCAL` | Sur l'appareil | Enregistré localement, aucun envoi tenté. |
| `PENDING` | En attente | Envoi commencé (par exemple photo téléversée) mais pas encore accepté par le serveur. |
| `SYNCED` | Synchronisé | Accepté par le serveur ; référence lisible reçue. |
| `FAILED` | Échec | Refus définitif, à traiter. |
| `CONFLICT` | À résoudre | Transition refusée car l'état serveur a changé. |

**Déclencheurs** : ouverture de l'application, événement `online`, retour au premier plan, minuterie de 60 s tant que l'application est ouverte, bouton manuel. Pas de Background Sync API. Un verrou `navigator.locks` empêche deux synchronisations simultanées.

## Alternatives étudiées

- Idempotence au niveau du lot seulement : un lot interrompu après traitement partiel serait ambigu. Écartée ; la clé de lot sert à la journalisation et à la limitation.
- Transaction unique pour tout le lot : une opération invalide bloquerait les autres. Écartée.
- Statut HTTP par opération (207 Multi-Status) : moins simple à typer dans le client généré. Écarté au profit d'un 200 avec résultats.

## Conséquences

- Chaque nouveau type d'opération ajoute un handler enregistré dans `apps/sync`.
- Les `SyncOperation` sont conservées pour l'audit ; leur durée de conservation dépend du §24.2 n°10.
- `GET /sync/pull` sera défini dans un ADR ultérieur (phase 2-3).
