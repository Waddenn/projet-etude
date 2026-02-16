# ADR-003 : Choix de Go pour le backend

## Statut
Accepté

## Contexte
L'application de démo "DevBoard" nécessite un backend API. Le choix du langage impacte la taille de l'image Docker, les performances, et la pertinence pédagogique.

## Décision
Nous développons le backend en **Go** avec le framework **Gin**.

## Arguments
- **Programme M1** : Golang fait partie des cours associés M1 (CI/CD DO, Usine Logicielle).
- **Image Docker ultra-légère** : un binaire Go compilé statiquement permet une image `scratch` de ~12 Mo, contre ~350 Mo pour une image basée sur `golang:1.22`. C'est l'argument Green IT le plus visible du projet.
- **Performances** : Go offre d'excellentes performances HTTP, idéal pour démontrer les métriques Prometheus et les tests de charge.
- **Métriques natives** : la librairie `prometheus/client_golang` permet d'exposer des métriques au format Prometheus sans dépendance externe.

## Alternatives envisagées
- **Node.js/Express** : image plus lourde (~180 Mo minimum), performances moindres sous charge.
- **Python/FastAPI** : nécessite un runtime Python dans l'image, ~120 Mo minimum.

## Conséquences
- L'équipe doit maîtriser les bases de Go (formations disponibles en cours M1).
- Le Dockerfile multi-stage est obligatoire pour obtenir l'image scratch.
