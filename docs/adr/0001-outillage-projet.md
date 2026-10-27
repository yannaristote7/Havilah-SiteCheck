# 0001 — Outillage du projet : uv, npm, versions de Python et de Node

- **Date** : 2026-10-27
- **Statut** : proposée
- **Exigences concernées** : §13.1, §18 du cdc

## Contexte

Le cdc impose Python/Django et Next.js, sans préciser les outils de gestion des dépendances ni les versions des environnements d'exécution. Il faut des installations reproductibles (CI, Docker, préproduction) et compatibles avec `pip-audit` et `npm audit` (§16.1).

## Décision

- Backend : **uv**, avec `pyproject.toml` et `uv.lock` commités, et **Python 3.13**.
- Frontend : **npm**, avec `package-lock.json` commité, et **Node 22 LTS**.
- Django **5.2 LTS** (support jusqu'en avril 2028). Montée vers la LTS suivante à planifier après sa sortie.

## Alternatives étudiées

- pip + pip-tools : standard, mais plus lent et moins pratique pour séparer les dépendances de dev. uv produit un lock exportable en `requirements.txt` pour pip-audit.
- Poetry : plus lourd et sans avantage pour une seule application.
- pnpm : plus rapide, mais `npm audit` est demandé explicitement et npm évite un outil de plus.
- Python 3.14 : apporte `uuid.uuid7()` natif, mais il est plus récent, et certaines roues binaires peuvent encore manquer. Un module `core/uuid7.py` comble le manque en 3.13.

## Conséquences

- Les images Docker et la CI installent uv (outil, pas une dépendance d'exécution).
- `uv export` alimente pip-audit.
- La montée de version de Python fera l'objet d'un ADR distinct.
