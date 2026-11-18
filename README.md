# Havilah SiteCheck

Application web mobile (PWA hors ligne) d'inspection terrain, de remontée des anomalies et des incidents, et de suivi des actions correctives, entre la Direction Générale d'Havilah Mining (Libreville) et le site de Tchimbanga (Gabon).

- Cahier des charges : [docs/cdc.md](docs/cdc.md)
- Décisions d'architecture : [docs/adr/](docs/adr/)
- Journal de la phase 1 : [docs/journal-phase-1.md](docs/journal-phase-1.md)

## Prérequis

- Windows 11 avec WSL2 (Ubuntu), dépôt cloné dans le système de fichiers Linux.
- Docker Desktop avec l'intégration WSL2 activée pour la distribution Ubuntu.
- L'utilisateur Linux doit pouvoir parler à Docker. Si `docker info` renvoie « permission denied » :

  ```bash
  sudo usermod -aG docker $USER
  # puis, depuis PowerShell : wsl --shutdown, et rouvrir le terminal Ubuntu
  ```

Aucune installation locale de Python ni de Node n'est nécessaire : tout tourne dans des conteneurs (Python 3.13 avec uv, Node 24).

## Démarrage

```bash
cp .env.example .env
make up
make migrate
make superuser
```

L'application est servie sur <http://localhost:8080> et l'API sous `/api/v1/`.

`make help` liste les autres commandes.

## Structure

```
backend/   projet Django (config/, apps/)
frontend/  application Next.js (PWA, export statique)
infra/     nginx/, docker/, scripts/
docs/      cahier des charges, ADR, journal
```

_Sections à compléter pendant la phase 1 : tests, tunnel HTTPS pour les téléphones, données fictives._
