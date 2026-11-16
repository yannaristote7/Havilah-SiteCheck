# 0007 — Apps Django supplémentaires : core, files, probe

- **Date** : 2026-10-27
- **Statut** : acceptée
- **Exigences concernées** : §13, §14 du cdc ; structure cible de CLAUDE.md

## Contexte

CLAUDE.md liste les apps `accounts`, `sites`, `templates`, `inspections`, `anomalies`, `incidents`, `actions`, `sync`, `notifications` et `audit`. La phase 1 a besoin d'un socle transverse, des pièces jointes (communes aux inspections, anomalies, incidents et actions) et d'un objet de test pour la preuve hors ligne, avant que les objets métier existent.

## Décision

- **`core`** : erreurs `application/problem+json`, identifiant de corrélation, logs JSON, healthcheck, génération et validation d'UUID v7, tâche Celery `heartbeat`.
- **`files`** : modèle `Attachment`, client S3, presign, confirm et URL de téléchargement.
- **`probe`** : modèle temporaire `ProbeNote`, support de la preuve hors ligne en phase 1. **Supprimé en phase 3**, quand les inspections et les anomalies prendront le relais (migration de suppression à valider à ce moment-là).
- En phase 1, `Site` et `Organization` sont dans `accounts`, car `Membership` en dépend directement. L'app `sites` sera créée en phase 2 pour les zones, catégories et équipements.

## Alternatives étudiées

- Placer `Attachment` dans `sync` : mélange deux responsabilités. Écartée.
- Utiliser d'emblée un vrai objet métier (anomalie) pour la preuve : anticipe la phase 4. Écartée.

## Conséquences

- CLAUDE.md sera mis à jour avec ces apps.
- La suppression de `probe` en phase 3 sera traitée comme une migration sensible (données de test uniquement).

## Tâche planifiée

**Phase 3 — suppression de l'app `probe`**, tâche explicite du plan de la phase 3, à réaliser une fois que les inspections et les anomalies couvrent la preuve hors ligne :

1. Vérifier qu'aucune `ProbeNote` n'est en attente sur un appareil de test (file vide) et qu'aucune donnée de production n'en dépend.
2. Retirer le handler `probe_note.create` du registre de `apps/sync` ; les opérations de ce type encore reçues sont refusées (`rejected`, `unknown_operation_type`).
3. Supprimer les écrans `/probe`, les tables Dexie et les tests e2e associés (migration Dexie versionnée).
4. Migration Django de suppression des tables de `probe`, présentée pour validation avant d'être écrite (migration qui supprime des données).
5. Retirer `apps.probe` de `INSTALLED_APPS`, régénérer le schéma OpenAPI et le client TypeScript, mettre à jour CLAUDE.md.
