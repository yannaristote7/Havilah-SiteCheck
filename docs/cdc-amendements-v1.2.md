# Amendements à reprendre dans le cahier des charges v1.2

Ce document liste les modifications du cdc v1.1 décidées pendant la phase 1. Chacune renvoie à l'ADR qui la justifie. Elles seront intégrées à `docs/cdc.md` lors de la publication de la v1.2.

## A1 — Révocation des appareils (ADR 0004, décidé le 2026-11-16)

### EF-AUT-04

**v1.1** :

> Chaque appareil est enregistré à la connexion (nom, navigateur, dernière synchronisation). L'utilisateur et l'administrateur peuvent le révoquer ; un appareil révoqué voit sa synchronisation refusée et ses données locales purgées au prochain contact.

**v1.2 proposée** :

> Chaque appareil est enregistré à la connexion (nom, navigateur, dernière synchronisation). Il peut être révoqué selon deux modes, journalisés avec leur motif :
> - **révocation avec synchronisation finale** (départ d'un employé), réservée à l'administrateur : au prochain contact, le serveur accepte les opérations créées avant l'heure de révocation, puis ordonne la purge complète des données locales. Passé un délai configurable (7 jours par défaut), les opérations sont refusées et leur nombre est journalisé ;
> - **révocation immédiate** (perte, vol, compromission), ouverte à l'administrateur et à l'utilisateur pour ses propres appareils : au prochain contact, la synchronisation est refusée et les données locales sont entièrement purgées, y compris les données non synchronisées ; le nombre d'opérations perdues est journalisé.
>
> Dans les deux cas, les sessions de l'appareil sont coupées et aucune nouvelle saisie n'est possible. Un changement de téléphone ne passe pas par une révocation : l'utilisateur synchronise puis se déconnecte (EF-OFF-09).

### EF-AUT-03

**v1.1** : « … Au-delà, une reconnexion est exigée avant toute nouvelle saisie ; les données en attente ne sont jamais supprimées. »

**v1.2 proposée** : « … Au-delà, une reconnexion est exigée avant toute nouvelle saisie ; les données en attente ne sont jamais supprimées, **sauf révocation immédiate de l'appareil (EF-AUT-04)**. »

### EF-OFF-08

**v1.1** : « Demande de stockage persistant au navigateur ; alerte à 80 % du quota ; aucune purge automatique de données non synchronisées. »

**v1.2 proposée** : « Demande de stockage persistant au navigateur ; alerte à 80 % du quota ; aucune purge automatique de données non synchronisées, **sauf sur ordre de révocation immédiate de l'appareil (EF-AUT-04), qui est journalisé**. »

### §16.2, puce « Révocation »

**v1.1** :

> **Révocation** d'un appareil perdu ou d'un employé sortant : sessions coupées immédiatement. Limite à connaître : les données encore non synchronisées sur un téléphone perdu ne peuvent pas être effacées à distance tant qu'il ne se reconnecte pas.

**v1.2 proposée** :

> **Révocation** d'un appareil, selon deux modes (EF-AUT-04) : avec synchronisation finale pour un employé sortant (les saisies en attente sont récupérées, puis l'appareil est purgé), immédiate pour un appareil perdu ou volé (l'appareil est purgé, saisies en attente comprises). Les sessions sont coupées immédiatement dans les deux cas. Limite à connaître : un téléphone qui ne se reconnecte pas ne peut pas être purgé à distance.
