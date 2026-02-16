# Configuration Tailscale - Accès distant au cluster K3s

## 🎯 Objectif

Permettre à l'équipe d'accéder aux services du cluster K3s (Grafana, Prometheus, Vault, DevBoard, ArgoCD) de n'importe où via Tailscale VPN.

## 📦 Installation effectuée

### Sur le node master K3s (192.168.1.40)

✅ Tailscale installé en mode **Subnet Router**
- Expose tout le réseau `192.168.1.0/24` via le VPN
- Permet l'accès aux 3 nodes K3s + tous les services

### Configuration système

```bash
# IP forwarding activé
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Device TUN configuré dans le LXC Proxmox
/dev/net/tun disponible
```

## 🔐 Première connexion (Admin uniquement)

### 1. Authentifier le node master

**Sur le master (192.168.1.40)** :

```bash
tailscale up --advertise-routes=192.168.1.0/24 \
             --accept-routes \
             --hostname=k3s-master
```

Cliquez sur le lien d'authentification affiché :
```
https://login.tailscale.com/a/XXXXXXXX
```

### 2. Activer le subnet routing (Admin Tailscale)

1. Aller sur https://login.tailscale.com/admin/machines
2. Trouver la machine `k3s-master`
3. Cliquer sur les `...` (menu)
4. Sélectionner **"Edit route settings..."**
5. **Approuver** la route `192.168.1.0/24`
6. Cliquer sur **"Save"**

✅ Le subnet routing est maintenant actif !

## 👥 Configuration pour l'équipe

### 1. Installer Tailscale (chaque membre)

**Linux/macOS** :
```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

**Windows** :
- Télécharger : https://tailscale.com/download/windows
- Installer et lancer l'application
- Se connecter avec le compte Tailscale de l'équipe

### 2. Configurer /etc/hosts (chaque membre)

Ajouter ces lignes à `/etc/hosts` (ou `C:\Windows\System32\drivers\etc\hosts` sur Windows) :

```
192.168.1.40 devboard.local argocd.devboard.local grafana.devboard.local prometheus.devboard.local vault.devboard.local alertmanager.devboard.local
```

### 3. Accéder aux services

Une fois Tailscale connecté :

| Service | URL | Identifiants |
|---------|-----|--------------|
| **DevBoard Frontend** | http://devboard.local | - |
| **DevBoard API** | http://devboard.local/api | - |
| **ArgoCD** | http://argocd.devboard.local | admin / kzIumMQcQRRpLlLl |
| **Grafana** | http://grafana.devboard.local | admin / prom-operator |
| **Prometheus** | http://prometheus.devboard.local | - |
| **Alertmanager** | http://alertmanager.devboard.local | - |
| **Vault** | http://vault.devboard.local | Token: root |

### 4. SSH sur les nodes K3s

```bash
# Node master
ssh root@192.168.1.40

# Agents
ssh root@192.168.1.41
ssh root@192.168.1.42
```

## 🔍 Vérification

### Vérifier la connexion Tailscale

```bash
# Voir les machines connectées
tailscale status

# Voir les routes disponibles
tailscale status --json | jq '.Peer[].Hostinfo.RoutableIPs'

# Ping le master via Tailscale
ping 192.168.1.40
```

### Tester les services

```bash
# Grafana
curl -I http://grafana.devboard.local
# → Devrait rediriger vers /login

# Prometheus
curl -I http://prometheus.devboard.local
# → Devrait rediriger vers /graph

# ArgoCD
curl -I http://argocd.devboard.local
# → Status 200 OK
```

## 🛠️ Dépannage

### Impossible de joindre 192.168.1.x

**Problème** : Subnet route non activée

**Solution** :
1. Vérifier sur https://login.tailscale.com/admin/machines
2. Vérifier que `k3s-master` a bien la route `192.168.1.0/24` **approved**

### Services inaccessibles

**Problème** : DNS ne résout pas les noms

**Solution** :
1. Vérifier `/etc/hosts` sur votre machine locale
2. Essayer avec l'IP directement : http://192.168.1.40

### Tailscale déconnecté

```bash
# Sur le master
ssh root@192.168.1.40
systemctl status tailscaled
tailscale status

# Redémarrer si nécessaire
systemctl restart tailscaled
```

## 📊 Architecture réseau

```
Internet
   ↓
[Tailscale VPN] ← Chaque membre de l'équipe
   ↓
k3s-master (192.168.1.40) ← Subnet Router
   ↓
   ├─→ 192.168.1.40 (master)  ← Grafana, Prometheus, ArgoCD, Vault
   ├─→ 192.168.1.41 (agent-1)
   └─→ 192.168.1.42 (agent-2)
```

## 🔐 Sécurité

- ✅ **Chiffrement WireGuard** : Tout le trafic est chiffré end-to-end
- ✅ **Authentification** : Chaque membre doit être autorisé dans Tailscale admin
- ✅ **Pas d'exposition publique** : Aucun port ouvert sur Internet
- ✅ **Subnet routing sécurisé** : Seul le réseau K3s (192.168.1.0/24) est exposé

## 📝 Gestion des accès (Admin)

### Ajouter un membre

1. Aller sur https://login.tailscale.com/admin/settings/users
2. Inviter par email
3. Le membre installe Tailscale et se connecte
4. Il a automatiquement accès au subnet 192.168.1.0/24

### Révoquer un accès

1. Aller sur https://login.tailscale.com/admin/settings/users
2. Trouver l'utilisateur
3. Cliquer sur **"Remove"**
4. Ses machines sont immédiatement déconnectées

## ⚠️ Notes importantes

1. **Point de défaillance unique** : Si le master (192.168.1.40) tombe, l'accès Tailscale est coupé
2. **Performance** : Tout le trafic passe par le master (peut être un goulot d'étranglement)
3. **Alternative future** : Installer Tailscale sur les 3 nodes pour plus de résilience

## 🔗 Ressources

- Documentation Tailscale : https://tailscale.com/kb/
- Subnet routers : https://tailscale.com/kb/1019/subnets
- LXC + Tailscale : https://tailscale.com/kb/1130/lxc-unprivileged
