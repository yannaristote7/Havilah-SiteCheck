# 0002 — Stockage objet servi sur la même origine, POST pré-signé

- **Date** : 2026-10-27
- **Statut** : proposée
- **Exigences concernées** : EF-OFF-04, EF-INS-03, AC-07, AC-16, §12.2, §16.1 du cdc

## Contexte

Les photos vont directement de l'appareil au stockage objet par URL pré-signée : l'API ne transporte pas les octets (§12.2). Le bucket est privé et les URL de téléchargement valent 15 min au plus. CLAUDE.md impose une origine unique et l'absence de CORS. Il faut aussi limiter la taille des fichiers envoyés : AC-07 exige moins de 400 Ko.

En local, le stockage est MinIO. MinIO a cessé de publier des images Docker communautaires fin 2025 et son dépôt est passé en maintenance. Ce point est à revérifier au moment de l'implémentation.

## Décision

1. Nginx expose le stockage sous **`/storage/`** sur la même origine que l'application et l'API (proxy vers MinIO en dev, vers le S3 retenu en préproduction et en production si nécessaire). Le client S3 qui signe est configuré avec l'URL publique (`S3_PUBLIC_ENDPOINT`) et l'adressage « path », pour que la signature porte sur l'hôte vu par le navigateur.
2. Le téléversement utilise un **POST pré-signé** (politique S3) dont les conditions imposent `content-length-range` (≤ 400 Ko) et `Content-Type: image/jpeg`. La clé est générée par le serveur.
3. Le serveur **confirme** chaque pièce jointe (`POST /attachments/{id}/confirm`) : taille, SHA-256, type réel (décodage Pillow) et absence d'EXIF GPS. Une pièce jointe non confirmée ne peut pas être référencée.
4. MinIO sert **uniquement au développement**, avec une image épinglée par son étiquette de version. La préproduction et la production utilisent un stockage S3 externe ou une alternative auto-hébergée compatible (Garage, SeaweedFS), choisie lors de l'étape préproduction.

## Alternatives étudiées

- URL pré-signée vers l'hôte MinIO ou S3 directement : impose une configuration CORS sur le bucket et un `connect-src` supplémentaire dans la CSP. Écartée.
- PUT pré-signé : plus simple, mais ne permet pas d'imposer une taille maximale côté stockage. Écarté.
- Téléversement via l'API Django : contraire au §12.2 et ne tient pas les pics de synchronisation. Écarté.

## Conséquences

- CSP `connect-src 'self'` suffisante.
- Si le S3 de production ne peut pas être placé derrière Nginx, il faudra un nouvel ADR (CORS restreint à l'origine de l'application).
- Le téléchargement passe par `/storage/` avec une URL signée de 15 min ; Nginx ne met pas ces réponses en cache.
