# ADR-002 : Choix de Loki (principal) + ELK (démo) pour les logs

## Statut
Accepté

## Contexte
Le cahier des charges mentionne ELK (Elasticsearch, Logstash, Kibana) pour la gestion des logs. Cependant, ELK nécessite au minimum 4 Go de RAM pour Elasticsearch seul, ce qui est problématique sur des machines d'étudiants.

## Décision
Nous utilisons **Loki + Promtail** comme solution de logs principale, et déployons une **instance ELK minimale en Docker Compose** uniquement pour démontrer notre maîtrise de l'outil.

## Arguments
- **Loki** : ~256 Mo de RAM, natif Grafana (même dashboards que Prometheus), requête LogQL similaire à PromQL.
- **ELK** : puissant mais gourmand (~4 Go RAM minimum), surconsommation non justifiée pour le volume de logs d'un projet de démo.
- **Green IT** : le choix Loki permet de réduire la consommation mémoire de 93% par rapport à ELK pour un usage équivalent.

## Alternatives envisagées
- **ELK seul** : risque de monopoliser les ressources et de bloquer l'avancement du projet.
- **Loki seul** : ne montre pas au jury la maîtrise d'ELK.

## Conséquences
- Le rapport Green IT inclura un comparatif chiffré Loki vs ELK (RAM, CPU, temps de démarrage).
- L'instance ELK demo est lancée uniquement pour les démonstrations via `make elk-up`.
