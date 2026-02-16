# Comment fonctionne le routage Ingress

## 📚 Explication du mécanisme

### 1️⃣ Le fichier /etc/hosts (résolution DNS locale)

Quand tu ajoutes dans `/etc/hosts` :
```
192.168.1.40 grafana.devboard.local
```

Cela dit à ton ordinateur : **"Quand tu vois grafana.devboard.local, remplace-le par 192.168.1.40"**

C'est comme un annuaire téléphonique local : nom → adresse IP.

### 2️⃣ La requête HTTP contient le hostname

Quand ton navigateur fait une requête HTTP, il envoie **deux informations** :

```http
GET / HTTP/1.1
Host: grafana.devboard.local    ← Le navigateur envoie le nom de domaine ici !
```

Même si l'IP de destination est 192.168.1.40, le navigateur **inclut le hostname dans la requête**.

### 3️⃣ Traefik lit le header "Host:" et route

**Traefik** (l'ingress controller de K3s) écoute sur le port 80 de **toutes** les IPs du cluster.

Quand il reçoit une requête, il :
1. Lit le header `Host: grafana.devboard.local`
2. Cherche dans ses règles Ingress : "Qui gère grafana.devboard.local ?"
3. Trouve l'ingress qui correspond :
   ```yaml
   spec:
     rules:
       - host: grafana.devboard.local  ← Match !
         http:
           paths:
             - backend:
                 service:
                   name: prometheus-grafana  ← Route vers ce service
   ```
4. Envoie la requête au service `prometheus-grafana`

---

## 🔄 Schéma du flux complet

```
┌─────────────────┐
│  Ton navigateur │
│  Firefox/Chrome │
└────────┬────────┘
         │
         │ 1. Tu tapes: http://grafana.devboard.local
         │
         ↓
┌─────────────────┐
│   /etc/hosts    │  ← Résolution DNS locale
│ grafana.devboard│     "grafana.devboard.local = 192.168.1.40"
│ .local →        │
│ 192.168.1.40    │
└────────┬────────┘
         │
         │ 2. Requête HTTP vers 192.168.1.40:80
         │    Header: Host: grafana.devboard.local
         │
         ↓
┌─────────────────┐
│   Traefik       │  ← Ingress Controller (sur K3s)
│   (192.168.1.40)│     Écoute sur port 80
│                 │
│   Lit header    │  3. Regarde le "Host:" dans la requête
│   "Host:"       │     → grafana.devboard.local
│                 │
│   Cherche       │  4. Trouve l'Ingress qui matche
│   l'Ingress     │     → grafana-ingress
│                 │
│   Route vers    │  5. Envoie vers le bon service K8s
│   le service    │     → prometheus-grafana:80
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Service K8s    │
│  prometheus-    │  6. Le pod Grafana répond
│  grafana        │
│  (Pod Grafana)  │
└────────┬────────┘
         │
         │ 7. Réponse HTML
         ↓
┌─────────────────┐
│  Ton navigateur │  8. Tu vois Grafana !
│  affiche Grafana│
└─────────────────┘
```

---

## 🎯 Pourquoi ça marche avec plusieurs services sur la même IP ?

C'est le principe du **Virtual Hosting** (hébergement virtuel), comme Apache/Nginx.

**Une seule IP** (192.168.1.40) peut servir **plusieurs sites** car :
- Traefik lit le header `Host:` de chaque requête
- Il route vers le bon backend selon ce header

### Exemple concret

#### Requête 1
```http
GET / HTTP/1.1
Host: grafana.devboard.local   ← Traefik route vers Grafana
```

#### Requête 2
```http
GET / HTTP/1.1
Host: prometheus.devboard.local   ← Traefik route vers Prometheus
```

#### Requête 3
```http
GET /api/health HTTP/1.1
Host: dev.devboard.local   ← Traefik route vers DevBoard backend
```

**Toutes vers 192.168.1.40:80, mais des destinations différentes !**

---

## 🔍 Vérification pratique

### Test 1 : Sans le bon hostname (ÉCHOUE)
```bash
curl http://192.168.1.40
# Traefik ne sait pas où router → 404 Not Found
```

### Test 2 : Avec le bon hostname en header (RÉUSSIT)
```bash
curl -H "Host: grafana.devboard.local" http://192.168.1.40
# Traefik lit "Host: grafana.devboard.local" → route vers Grafana → 200 OK
```

### Test 3 : Via le nom de domaine après /etc/hosts (RÉUSSIT)
```bash
curl http://grafana.devboard.local
# /etc/hosts traduit grafana.devboard.local → 192.168.1.40
# Le navigateur envoie automatiquement "Host: grafana.devboard.local"
# Traefik route correctement → 200 OK
```

---

## 📋 Résumé

1. **`/etc/hosts`** : Résolution locale nom → IP (remplace le DNS)
2. **Header HTTP `Host:`** : Le navigateur envoie le nom de domaine dans la requête
3. **Traefik Ingress** : Lit ce header et route vers le bon service Kubernetes
4. **Virtual Hosting** : Une IP, plusieurs services différenciés par le hostname

C'est exactement comme un serveur web Apache avec plusieurs VirtualHosts, mais au niveau Kubernetes !

---

## 🛠️ Configuration dans K8s

Voici ce qui a été créé pour que ça fonctionne :

### Ingress pour Grafana (k8s/ingress-monitoring.yaml)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
spec:
  rules:
    - host: grafana.devboard.local   ← Traefik match sur ce hostname
      http:
        paths:
          - path: /
            backend:
              service:
                name: prometheus-grafana   ← Route vers ce service
                port:
                  number: 80
```

Traefik lit automatiquement tous les Ingress du cluster et crée les routes correspondantes.
