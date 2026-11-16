# 0005 — Modèle de permissions rôle × site

- **Date** : 2026-10-27
- **Statut** : acceptée
- **Exigences concernées** : EF-AUT-05, EF-REF-05, AC-01, AC-10, §6, §16.1 du cdc

## Contexte

Les permissions sont vérifiées côté serveur, sur chaque requête et sur chaque objet (§6). Un utilisateur peut avoir des rôles différents selon les sites. Le rôle HSE reste à confirmer (§24.2 n°5) et la matrice du §6 contient des conditions « (✓) ».

## Décision

1. **Membership** (utilisateur, site, rôle, actif) porte le rôle par site. Rôles : `DG`, `SITE_MANAGER`, `HSE`, `INSPECTOR`, `TECHNICIAN`, `READER`. La DG accède aux sites pour lesquels elle a une appartenance (« sites autorisés »).
2. L'**administrateur technique** est un drapeau utilisateur (`is_tech_admin`) qui donne accès à l'administration Django pour le paramétrage, et **aucun accès aux données opérationnelles par l'API**.
3. Une **table de politique unique** (`apps/accounts/policy.py`) associe chaque action aux rôles autorisés. Les conditions « (✓) » du §6 sont implémentées dans des fonctions de prédicat à côté de la table.
4. Toute vue passe par `SiteScopedQuerySet.for_user(user, action)` et par la classe DRF `SiteRolePermission(action)`, qui vérifie aussi chaque objet. `Model.objects.all()` est interdit dans les vues.
5. Codes de réponse : anonyme → 401 ou 403 ; objet d'un site non autorisé → **404** (on ne révèle pas son existence) ; site autorisé mais rôle insuffisant → **403**.
6. Un **harnais de tests négatifs** paramétré couvre chaque endpoint (anonyme, autre site, rôle insuffisant). Un test transverse échoue si une route de l'API n'y est pas déclarée.
7. **`IncidentPerson` n'est jamais enregistré dans l'administration Django**, ni comme modèle ni comme inline d'un autre modèle (`Incident` compris). Un test parcourt `admin.site._registry` et les inlines de chaque `ModelAdmin` et échoue s'il y trouve `IncidentPerson`. Le test est écrit dès la phase 1 (il passe tant que le modèle n'existe pas) pour qu'il soit en place quand le modèle arrivera en phase 4.

## Alternatives étudiées

- django-guardian (permissions par objet en base) : stocke une ligne par objet et utilisateur, coûteux à 1 000 utilisateurs et inutile puisque la règle dépend du site. Écartée.
- Permissions Django standard (groupes) : ignorent le site. Écartée.
- Matrice configurable en base : les rôles sont fixés par le cdc ; seule la matrice SLA et les référentiels doivent être configurables. Écartée pour la V1.

## Conséquences

- Changer la matrice du §6 revient à modifier un seul fichier, couvert par des tests.
- Chaque nouvel endpoint doit être déclaré dans le harnais, sinon la CI échoue.
- Les données `IncidentPerson` ne sont consultables que par l'API, avec les rôles autorisés ; l'administrateur technique ne peut pas les voir par l'administration Django.
- L'administrateur technique doit disposer d'un autre compte, avec appartenances, s'il doit consulter des données opérationnelles.
