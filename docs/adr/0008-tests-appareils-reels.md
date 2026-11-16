# 0008 — Tests sur appareils réels : tunnel HTTPS puis préproduction

- **Date** : 2026-10-27
- **Statut** : acceptée
- **Exigences concernées** : AC-04, §11 (compatibilité), §20, §21.1 du cdc

## Contexte

Une fonctionnalité hors ligne n'est terminée qu'après un test sur un vrai Android et un vrai iPhone, avec l'application installée. Le Service Worker exige un contexte sécurisé : iOS refuse un certificat auto-signé, et un téléphone joint difficilement un port de WSL2 derrière Docker Desktop.

## Décision

Validée le 2026-10-27 :

1. **Développement** : un tunnel HTTPS (Cloudflare Tunnel ou équivalent) depuis WSL2 vers `http://localhost:8080`. Le domaine du tunnel est ajouté à `ALLOWED_HOSTS` et `CSRF_TRUSTED_ORIGINS` par variables d'environnement, jamais en dur.
2. **Démo à Tchimbanga** : une préproduction sur un VPS ouvert au nom d'Havilah (§22), avec certificat Let's Encrypt, données fictives seulement.
3. Le protocole et les fiches de résultat sont décrits dans `docs/test-appareils.md`.
4. **Règles d'usage du tunnel** :
   - uniquement avec des données fictives ;
   - fermé en dehors des sessions de test ;
   - URL non partagée (ni dans le dépôt, ni dans un ticket, ni dans une messagerie).

## Alternatives étudiées

- Certificat auto-signé avec autorité installée sur le téléphone : lourd sur iOS et non représentatif des appareils réels. Écartée.
- Préproduction seule : chaque test impose un déploiement. Écartée.

## Conséquences

- Un outil de tunnel est nécessaire sur le poste de développement (pas une dépendance du projet).
- Le tunnel expose temporairement l'environnement de dev : les règles d'usage du point 4 limitent cette exposition.
- La préproduction dépend des comptes Havilah et de la réponse au §24.2 n°9.
