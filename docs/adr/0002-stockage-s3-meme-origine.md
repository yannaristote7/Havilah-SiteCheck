# 0002 — Stockage objet : même origine en pilote, téléversement direct ensuite

- **Date** : 2026-10-27, révisée le 2026-11-16
- **Statut** : acceptée (2026-11-16)
- **Exigences concernées** : EF-OFF-04, EF-INS-03, AC-07, AC-16, §12.2, §12.3, §16.1, §21.2 du cdc

## Contexte

Les photos vont directement de l'appareil au stockage objet par URL pré-signée : **le serveur d'API ne transporte pas les fichiers** (§12.2). À 1 000 utilisateurs, le pic de synchronisation représente environ 2 Go en 30 minutes (§12.1). Le bucket est privé et les URL de téléchargement valent 15 minutes au plus (AC-16). Les photos doivent peser moins de 400 Ko (AC-07). D'autres pièces jointes (PDF, documents) viendront dans les phases suivantes, avec des tailles plus grandes.

Deux questions restaient ouvertes : où sont stockés les fichiers en production, et est-ce que leurs octets passent par le VPS ?

**Situation de MinIO (vérifiée le 2026-11-16)** : l'édition communautaire n'est plus maintenue. Plus d'images Docker ni de binaires officiels depuis octobre 2025, maintenance seule en décembre 2025, dépôt GitHub archivé le 25 avril 2026, images retirées de Docker Hub en septembre 2026. Plusieurs failles publiées en 2026 n'ont pas de correctif public. MinIO ne doit plus être utilisé, même en développement.

## Décision

### 1. Deux étapes pour le chemin des octets

| | **Étape A — pilote (palier 1 du §12.3)** | **Étape B — à partir du palier 2** |
|---|---|---|
| Stockage | Service compatible S3 auto-hébergé, dans un conteneur sur le VPS | Fournisseur S3 externe |
| Chemin d'un envoi | Téléphone → Nginx → stockage | Téléphone → fournisseur, directement |
| Les octets passent par le VPS ? | **Oui, par Nginx uniquement**, jamais par Django ni Gunicorn | **Non** |
| Même origine | Oui : pas de CORS, CSP `connect-src 'self'` | Non : CORS limité à l'origine de l'application, CSP élargie au domaine du fournisseur |

- **Étape A** respecte le §12.2 (l'API ne transporte pas les fichiers) : Nginx transmet le flux sans le mettre en mémoire tampon. Le volume du pilote est faible : environ 50 inspections par jour et 2 à 3 photos de 250 Ko, soit environ 30 Mo par jour et 11 Go par an.
- **Étape B** est nécessaire avant le palier 2 (100 à 300 utilisateurs) : au palier 3, 2 Go en 30 minutes saturerait la bande passante et le disque d'un VPS. Le basculement fera l'objet d'un ADR qui choisira le fournisseur. Ce choix dépend de la réponse du client sur l'hébergement hors du Gabon (§24.2 n°9, §16.3).
- **Le code est le même dans les deux cas** : `POST /attachments/presign` renvoie une adresse complète et les champs du formulaire, et `GET /attachments/{id}/download-url` renvoie une adresse complète. L'application envoie le fichier à l'adresse reçue. Passer de A à B se fait par configuration (adresse du stockage, CORS, CSP), sans modifier l'application.
- Critère de bascule, à vérifier chaque mois pendant le pilote : décision de passer au palier 2, **ou** stockage photo au-delà de 50 % du disque du VPS, **ou** synchronisation qui ralentit l'API pendant les pics.

### 2. Exposition sur la même origine (étape A)

- Nginx expose le bucket sous **son propre nom** (`/hsc-files/`), **sans réécrire le chemin** et en transmettant l'en-tête `Host` d'origine. La signature S3 porte sur l'hôte et le chemin vus par le navigateur ; un préfixe retiré par Nginx (`/storage/` → `/`) la rendrait invalide.
- Le client S3 qui signe utilise l'adresse publique (`S3_PUBLIC_ENDPOINT`) et l'adressage « path ». Il utilise l'adresse interne pour les opérations du serveur (vérification, lecture).
- Sur `/hsc-files/`, Nginx ajoute `X-Content-Type-Options: nosniff`, `Content-Security-Policy: sandbox` et `Cache-Control: no-store`. Les fichiers autres que des images sont servis avec `Content-Disposition: attachment`. Ces fichiers sont servis depuis l'origine de l'application : un fichier piégé ne doit pas pouvoir y exécuter de script.

### 3. Téléversement par POST pré-signé, plafond par type

- Le téléversement utilise un **POST pré-signé** (politique S3). Ses conditions imposent la clé générée par le serveur, le `Content-Type` et `content-length-range`. Le stockage refuse donc lui-même un fichier trop gros.
- Types acceptés et plafonds **configurables** par variable d'environnement (`ATTACHMENT_TYPES`), avec ces valeurs par défaut :

| Type | Plafond par défaut | Vérification du type réel | Phase |
|---|---|---|---|
| Photo `image/jpeg` | **400 000 octets** (AC-07 : moins de 400 Ko) | Décodage Pillow, absence d'EXIF GPS | 1 |
| Document `application/pdf` | **10 Mo** | Signature `%PDF-` | Désactivé par défaut ; activé par configuration dans la phase qui en a besoin |
| Autres (Word, Excel…) | — | — | Non acceptés tant qu'un besoin n'est pas validé |

- Le plafond est appliqué trois fois : à la demande d'URL (taille déclarée), par le stockage (politique POST) et à la confirmation (taille réelle).
- Le serveur **confirme** chaque pièce jointe (`POST /attachments/{id}/confirm`) : taille, SHA-256, type réel. Une pièce jointe non confirmée ne peut pas être référencée.

### 4. Logiciel de stockage

- **Garage** (Deuxfleurs, AGPL-3.0, version 2.5.0 publiée le 2026-10-24) remplace MinIO, en développement et pour le pilote (étape A). Avoir le même produit dans les deux environnements évite les écarts de comportement. Garage est léger, conçu pour l'auto-hébergement, et implémente le POST pré-signé (PostObject), les URL pré-signées et CORS.
- Avant l'étape 11 du plan, un **test de compatibilité** automatisé tourne contre le stockage. Il vérifie :
  - qu'un fichier de **plus de 400 000 octets** envoyé par POST pré-signé est **refusé** par le stockage (condition `content-length-range`) ;
  - qu'un `Content-Type` différent et qu'une clé différente de ceux de la politique sont refusés ;
  - qu'une URL de téléchargement expirée est refusée.

  Il est rejoué en CI et à chaque changement de version du stockage.
- **Si le stockage n'applique pas `content-length-range`**, le contrôle de taille réelle à la confirmation (`/confirm`) devient la **protection principale** : un fichier trop gros est alors refusé à la confirmation, supprimé du stockage par le serveur et jamais référencé. Nginx limite en plus la taille du corps de requête sur `/hsc-files/` (`client_max_body_size`, réglé sur le plus grand plafond actif). Le résultat du test est consigné dans le journal de phase 1.
- Si Garage échoue à ce test, **SeaweedFS** (Apache-2.0, version 4.54 publiée le 2026-11-16, POST pré-signé présent dans le code) prend sa place, sans autre changement.
- L'image est épinglée par sa version et son empreinte.

## Alternatives étudiées

- **Relais Nginx vers un fournisseur externe** : le POST fonctionne, mais un téléchargement pré-signé est signé pour l'hôte du fournisseur, pas pour celui de l'application. Il faudrait que Nginx signe à nouveau chaque requête, et chaque octet traverserait le VPS deux fois. Écartée.
- **Téléversement direct (étape B) dès le pilote** : choix du fournisseur et de son pays nécessaire tout de suite, alors que le §24.2 n°9 n'est pas tranché. Plus de configuration (CORS, CSP) pour 10 à 30 utilisateurs. Écartée pour le pilote.
- **Téléversement via l'API Django** : contraire au §12.2 et ne tient pas les pics de synchronisation. Écartée.
- **PUT pré-signé** : plus simple, mais ne permet pas d'imposer une taille maximale côté stockage. Écartée. Certains fournisseurs n'acceptent que le PUT (Cloudflare R2, Backblaze B2) : ils sont exclus pour l'étape B.
- **Garder une ancienne image MinIO** : aucun correctif de sécurité, image introuvable sur Docker Hub. Écartée. Les reprises communautaires (par exemple pgsty/silo) sont trop jeunes pour en dépendre.
- **RustFS** : jeune, et une faille de validation des politiques POST a été corrigée en février 2026. Écartée pour l'instant.

## Conséquences

- MinIO disparaît du plan de phase 1 : `docker-compose.yml` utilise Garage, avec un job d'initialisation (disposition du cluster, clé d'accès, bucket privé).
- Garage ne gère pas le versionnage des objets, demandé au §21.2. Les clés sont générées par le serveur et les fichiers ne sont jamais remplacés ni supprimés (archivage logique) : la protection vient de la **réplication quotidienne vers un second fournisseur**, à mettre en place au plus tard en phase 6. L'outil de réplication sera soumis à validation.
- Étape A : le disque et la bande passante du VPS portent les fichiers. Ils sont surveillés (alerte disque du §21.1).
- Étape B : nouvel ADR (fournisseur, pays d'hébergement, CORS, CSP `connect-src` et `img-src`, migration des fichiers existants). Le fournisseur doit accepter le POST pré-signé avec `content-length-range`.
- **Licence de Garage : AGPL-3.0.** Cette licence impose de publier le code source d'une version **modifiée** de Garage mise à disposition par le réseau. Garage est utilisé **sans modification**, dans son image officielle, comme service séparé qui communique avec l'application par l'API S3 : l'application n'est pas une œuvre dérivée, et aucune obligation ne s'applique à son code. Si Havilah ou le prestataire modifiait un jour Garage lui-même, il faudrait publier ces modifications.
- **Risque à présenter au client** : pas de versionnage des objets dans Garage. Il est compensé par l'absence de remplacement et de suppression des fichiers, et par la réplication quotidienne vers un second fournisseur.
