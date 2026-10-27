# 0007 — Apps Django supplémentaires : core, files, probe

- **Date** : 2026-10-27
- **Statut** : proposée
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
