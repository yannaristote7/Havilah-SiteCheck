# 0004 — Appareils, révocation et fenêtre hors ligne

- **Date** : 2026-10-27
- **Statut** : proposée
- **Exigences concernées** : EF-AUT-03, EF-AUT-04, EF-OFF-08, EF-OFF-10 du cdc

## Contexte

EF-AUT-04 demande qu'un appareil révoqué voie « ses données locales purgées au prochain contact ». Or EF-AUT-03, EF-OFF-08 et CLAUDE.md interdisent toute suppression automatique de données non synchronisées, et un appareil révoqué ne peut plus synchroniser. Les deux exigences sont contradictoires pour les données en attente.

## Décision

Arbitrage validé le 2026-10-27, qui **amende EF-AUT-04** :

1. Le client génère un **`device_id`** (UUID v7) au premier lancement et le conserve dans IndexedDB. Ce n'est pas un jeton d'authentification. Il est envoyé à la connexion et dans l'en-tête `X-Device-Id` de chaque synchronisation. Le serveur crée ou met à jour l'objet `Device` (libellé, navigateur, dernière synchronisation, `revoked_at`).
2. Révocation par l'utilisateur ou l'administrateur : suppression immédiate des sessions liées et journalisation dans l'audit. Toute requête de cet appareil reçoit **403 `device_revoked`**.
3. À réception de `device_revoked`, le client **purge les données déjà synchronisées et les référentiels**, mais **conserve les opérations en attente**, verrouillées : aucune nouvelle saisie, aucun envoi. L'export de secours chiffré (EF-OFF-10, phase ultérieure) permettra au support de les récupérer.
4. **Fenêtre hors ligne de 96 h** (EF-AUT-03) : le client enregistre `last_online_auth_at` après chaque `GET /auth/me` réussi. Au-delà de 96 h, toute nouvelle saisie est bloquée jusqu'à une reconnexion ; la file reste conservée et consultable.

## Alternatives étudiées

- Purge totale (lecture littérale d'EF-AUT-04) : perte de données terrain. Écartée.
- Accepter un dernier lot d'un appareil révoqué : dangereux si l'appareil est perdu ou volé. Écartée.

## Conséquences

- Le cdc v1.2 doit reprendre cet amendement d'EF-AUT-04.
- Risque résiduel (§16.2) : les données en attente sur un téléphone perdu restent sur l'appareil.
- La fenêtre de 96 h repose sur l'horloge de l'appareil, que l'utilisateur peut modifier ; la session serveur de 7 jours reste l'autorité.
