# 0001 — Outillage du projet : uv, npm, versions de Python et de Node

- **Date** : 2026-10-27
- **Statut** : acceptée
- **Exigences concernées** : §13.1, §16.1, §18, AC-19 du cdc

## Contexte

Le cdc impose Python/Django et Next.js, sans préciser les outils de gestion des dépendances ni les versions des environnements d'exécution. Il faut des installations reproductibles (CI, Docker, préproduction) et compatibles avec `pip-audit` et `npm audit` (§16.1).

## Décision

- Backend : **uv**, avec `pyproject.toml` et `uv.lock` commités, et **Python 3.13**.
- Frontend : **npm**, avec `package-lock.json` commité, et **Node 24 LTS** (Node 22 sort de maintenance en avril 2027, avant la fin prévue du pilote).
- Django **5.2 LTS** (support jusqu'en avril 2028). Montée vers la LTS suivante à planifier après sa sortie.
- Analyses de sécurité en CI (§16.1) :
  - **Semgrep** dès la phase 1, **bloquant** sur les règles de sévérité `ERROR`, non bloquant sur les autres.
  - **Trivy** (images Docker) dès la phase 1 en **mode rapport** (non bloquant), puis **bloquant en phase 6**.
  - Les deux s'exécutent dans la CI uniquement (image ou action épinglée par empreinte ou SHA de commit), ce ne sont pas des dépendances du projet.

## Alternatives étudiées

- pip + pip-tools : standard, mais plus lent et moins pratique pour séparer les dépendances de dev. uv produit un lock exportable en `requirements.txt` pour pip-audit.
- Poetry : plus lourd et sans avantage pour une seule application.
- pnpm : plus rapide, mais `npm audit` est demandé explicitement et npm évite un outil de plus.
- Semgrep et Trivy en phase 6 seulement (proposition initiale) : les problèmes s'accumuleraient pendant cinq phases. Écartée.
- Python 3.14 : apporte `uuid.uuid7()` natif, mais il est plus récent, et certaines roues binaires peuvent encore manquer. Un module `core/uuid7.py` comble le manque en 3.13.

## Conséquences

- Les images Docker et la CI installent uv (outil, pas une dépendance d'exécution).
- `uv export` alimente pip-audit.
- La montée de version de Python fera l'objet d'un ADR distinct.
- Les actions GitHub tierces sont épinglées par SHA de commit : les étiquettes de `aquasecurity/trivy-action` ont été détournées en mars 2026 (CVE-2026-33634).
- Le passage de Trivy en mode bloquant est une tâche explicite de la phase 6.
