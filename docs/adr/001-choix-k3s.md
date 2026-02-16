# ADR-001 : Choix de K3s comme orchestrateur

## Statut
Accepté

## Contexte
Le cahier des charges propose Kubernetes, K3s ou Minikube comme solutions d'orchestration. Nous devons choisir une solution qui soit réaliste, certifiée CNCF, et adaptée à nos ressources matérielles.

## Décision
Nous choisissons **K3s** comme orchestrateur de conteneurs.

## Arguments
- **Certifié CNCF** : K3s est un Kubernetes certifié. Toute configuration K3s est portable vers un K8s de production.
- **Léger** : ~512 Mo de RAM contre 2+ Go pour Minikube. C'est un argument Green IT mesurable.
- **Multi-node** : contrairement à Minikube (single-node par défaut), K3s supporte nativement un cluster multi-node (1 server + N agents), ce qui est essentiel pour démontrer la résilience et le chaos engineering.
- **Traefik inclus** : K3s embarque Traefik comme Ingress Controller, réduisant la configuration nécessaire.
- **Installation simple** : une seule commande `curl | sh`, facilement automatisable avec Ansible.

## Alternatives envisagées
- **Minikube** : limité à un seul noeud, plus lourd en RAM, pas adapté pour la démo de résilience.
- **K8s complet (kubeadm)** : complexité d'installation excessive pour un projet étudiant, sans valeur ajoutée pédagogique.

## Conséquences
- L'équipe doit provisionner au minimum 3 VMs (1 server + 2 agents) ou utiliser des VMs locales via Vagrant.
- Les manifestes K8s standard fonctionnent sans modification sur K3s.
