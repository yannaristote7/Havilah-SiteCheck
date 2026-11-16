# 0006 — Service Worker et routage en export statique

- **Date** : 2026-10-27
- **Statut** : acceptée
- **Exigences concernées** : EF-OFF-01, EF-OFF-05, §11, §13.1 du cdc

## Contexte

Next.js est en `output: 'export'` : pas de serveur Node.js, donc pas de route dynamique générée à la demande. Le cdc laisse le choix entre Serwist et Workbox. Les intégrations Serwist pour Next.js dépendent du bundler (webpack ou Turbopack), qui évolue d'une version à l'autre.

## Décision

1. **Serwist en mode injectManifest**, exécuté **après** `next build` sur le dossier `out/`. Le Service Worker (`src/sw/sw.ts`) est compilé séparément. On ne dépend ainsi ni de webpack ni de Turbopack.
2. Le Service Worker **précache l'application** et fournit un repli de navigation hors ligne. Il **ne met en cache aucune réponse `/api/`** : les données métier et la file passent par IndexedDB (Dexie), seule source de vérité locale.
3. Mise à jour contrôlée : un bandeau « nouvelle version disponible » ; l'activation ne se fait pas pendant une synchronisation.
4. **Aucune route à segment dynamique** : les identifiants passent en paramètre de requête (`/probe?id=…`). Nginx sert `$uri`, `$uri.html`, puis la page de repli.

## Alternatives étudiées

- `@serwist/next` (intégration au bundler) : plus simple au départ, mais lié au bundler. Écartée.
- Workbox (`workbox-build` injectManifest) : équivalent fonctionnellement, mais Serwist en est le successeur maintenu, typé en TypeScript.
- Cache API pour les réponses de l'API : deux sources de vérité locales, risque d'incohérence. Écartée.

## Conséquences

- Script `build` en deux temps : `next build` puis injection du manifeste.
- Les tests Playwright vérifient le démarrage hors ligne après installation du Service Worker.
- Les changements de schéma Dexie sont versionnés et testés sur une base peuplée, pour ne jamais perdre la file lors d'une mise à jour.
