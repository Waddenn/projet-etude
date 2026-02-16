# Déploiement Helm et Kubernetes - Documentation

## Vue d'ensemble

Le déploiement de DevBoard sur Kubernetes utilise **Helm** pour la gestion des packages et **Kustomize** pour les variantes par environnement.

---

## 1. Chart Helm DevBoard

### 📁 Structure

```
helm/devboard/
├── Chart.yaml              # Métadonnées du chart
├── values.yaml             # Valeurs par défaut
├── values-dev.yaml         # Overrides pour dev
├── values-prod.yaml        # Overrides pour prod
└── templates/
    ├── backend.yaml        # Deployment + Service + HPA backend
    ├── frontend.yaml       # Deployment + Service frontend
    ├── postgres.yaml       # Deployment + Service + PVC postgres
    ├── ingress.yaml        # Ingress Traefik
    └── secrets.yaml        # Secrets K8s
```

### 📋 Chart.yaml

```yaml
apiVersion: v2
name: devboard
description: Plateforme de gestion de projets ESN - DevBoard
type: application
version: 0.1.0
appVersion: "1.0.0"
```

### ⚙️ values.yaml (défaut)

```yaml
backend:
  image:
    repository: ghcr.io/votre-groupe/devboard/backend
    tag: latest
    pullPolicy: IfNotPresent
  replicas: 2
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 500m
      memory: 256Mi
  hpa:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPU: 70

frontend:
  image:
    repository: ghcr.io/votre-groupe/devboard/frontend
    tag: latest
    pullPolicy: IfNotPresent
  replicas: 2
  resources:
    requests:
      cpu: 50m
      memory: 32Mi
    limits:
      cpu: 200m
      memory: 128Mi

postgres:
  image: postgres:16-alpine
  storage: 5Gi
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

secrets:
  dbUsername: devboard
  dbPassword: changeme-in-production
  jwtSecret: changeme-jwt-secret-minimum-32-chars

ingress:
  enabled: true
  host: devboard.local

networkPolicies:
  enabled: true
```

### ⚙️ values-dev.yaml (override pour dev)

```yaml
backend:
  image:
    repository: docker.io/library/devboard-backend
    tag: latest
    pullPolicy: Never  # Images locales
  replicas: 1
  hpa:
    enabled: false

frontend:
  image:
    repository: docker.io/library/devboard-frontend
    tag: latest
    pullPolicy: Never
  replicas: 1

postgres:
  storage: 1Gi

ingress:
  host: dev.devboard.local

secrets:
  dbPassword: <voir .env.secrets>  # généré par make generate-secrets

networkPolicies:
  enabled: false
```

---

## 2. Templates Helm

### backend.yaml

Crée :
- **Deployment** : Pods backend avec liveness/readiness probes
- **Service** : Expose le backend sur port 8080
- **HorizontalPodAutoscaler** (optionnel) : Auto-scaling basé sur CPU

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-backend
spec:
  replicas: {{ .Values.backend.replicas }}
  selector:
    matchLabels:
      component: backend
  template:
    spec:
      containers:
        - name: backend
          image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
          imagePullPolicy: {{ .Values.backend.image.pullPolicy }}
          ports:
            - containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ .Release.Name }}-secrets
                  key: database-url
          livenessProbe:
            httpGet:
              path: /api/health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            {{- toYaml .Values.backend.resources | nindent 12 }}
```

### frontend.yaml

Crée :
- **Deployment** : Pods frontend (Nginx + React)
- **Service** : Expose le frontend sur port 80

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-frontend
spec:
  replicas: {{ .Values.frontend.replicas }}
  template:
    spec:
      containers:
        - name: frontend
          image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
          imagePullPolicy: {{ .Values.frontend.image.pullPolicy }}
          env:
            - name: BACKEND_HOST
              value: "{{ .Release.Name }}-backend"
          resources:
            {{- toYaml .Values.frontend.resources | nindent 12 }}
```

### postgres.yaml

Crée :
- **Deployment** : Pod PostgreSQL
- **Service** : Expose PostgreSQL sur port 5432
- **PersistentVolumeClaim** : Stockage persistant

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-postgres
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: postgres
          image: {{ .Values.postgres.image }}
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: {{ .Release.Name }}-secrets
                  key: db-username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: {{ .Release.Name }}-secrets
                  key: db-password
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: postgres-data
          persistentVolumeClaim:
            claimName: {{ .Release.Name }}-postgres-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Release.Name }}-postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.postgres.storage }}
```

### ingress.yaml

Crée un **Ingress Traefik** qui route :
- `/api/*` → backend:8080
- `/*` → frontend:80

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: {{ .Values.ingress.host }}
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: {{ .Release.Name }}-backend
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .Release.Name }}-frontend
                port:
                  number: 80
{{- end }}
```

### secrets.yaml

Crée un **Secret** avec les credentials :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ .Release.Name }}-secrets
type: Opaque
stringData:
  db-username: {{ .Values.secrets.dbUsername }}
  db-password: {{ .Values.secrets.dbPassword }}
  database-url: "postgres://{{ .Values.secrets.dbUsername }}:{{ .Values.secrets.dbPassword }}@{{ .Release.Name }}-postgres:5432/devboard?sslmode=disable"
  jwt-secret: {{ .Values.secrets.jwtSecret }}
```

---

## 3. Déployer avec Helm

### 🚀 Installation

```bash
# Environnement DEV
helm upgrade --install devboard helm/devboard/ \
  -f helm/devboard/values-dev.yaml \
  -n devboard-dev \
  --create-namespace

# Environnement PROD
helm upgrade --install devboard helm/devboard/ \
  -f helm/devboard/values-prod.yaml \
  -n devboard-prod \
  --create-namespace
```

### 📊 Vérifier le déploiement

```bash
# Status du release
helm status devboard -n devboard-dev

# Lister les releases
helm list -A

# Voir les ressources créées
kubectl get all -n devboard-dev

# Voir les valeurs utilisées
helm get values devboard -n devboard-dev
```

### 🔄 Mise à jour

```bash
# Modifier values-dev.yaml puis :
helm upgrade devboard helm/devboard/ \
  -f helm/devboard/values-dev.yaml \
  -n devboard-dev

# Ou changer une valeur à la volée :
helm upgrade devboard helm/devboard/ \
  --set backend.replicas=3 \
  -n devboard-dev
```

### 🗑️ Désinstallation

```bash
helm uninstall devboard -n devboard-dev

# Supprimer aussi le namespace
kubectl delete namespace devboard-dev
```

### 🔙 Rollback

```bash
# Voir l'historique
helm history devboard -n devboard-dev

# Rollback vers la révision précédente
helm rollback devboard -n devboard-dev

# Rollback vers une révision spécifique
helm rollback devboard 2 -n devboard-dev
```

---

## 4. Kustomize (alternative)

### 📁 Structure

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── postgres-deployment.yaml
│   └── postgres-service.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patches/
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patches/
    └── prod/
        ├── kustomization.yaml
        └── patches/
```

### 🎯 Principe

- **base/** : Manifests communs
- **overlays/** : Customisations par environnement (patches)

### 🚀 Déployer avec Kustomize

```bash
# Dev
kubectl apply -k k8s/overlays/dev/

# Staging
kubectl apply -k k8s/overlays/staging/

# Prod
kubectl apply -k k8s/overlays/prod/

# Dry-run (voir ce qui sera appliqué)
kubectl apply -k k8s/overlays/dev/ --dry-run=client -o yaml
```

---

## 5. Namespaces

### 📦 Namespaces créés

| Namespace         | Usage                      | Ressources                          |
|-------------------|----------------------------|-------------------------------------|
| `devboard-dev`    | Développement              | Backend, Frontend, Postgres         |
| `devboard-staging`| Pré-production             | Identique à prod (miroir)           |
| `devboard-prod`   | Production                 | Backend, Frontend, Postgres (HA)    |
| `monitoring`      | Observabilité              | Prometheus, Grafana, Loki           |
| `security`        | Sécurité                   | Vault                               |
| `kube-system`     | Système K3s                | CoreDNS, Traefik, metrics-server    |

### 🔧 Créer un namespace

```bash
kubectl create namespace devboard-staging

# Ou via manifest
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: devboard-staging
  labels:
    env: staging
EOF
```

---

## 6. Resource Quotas et Limits

### 🎯 Limiter les ressources par namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: devboard-quota
  namespace: devboard-dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
```

### 📊 Voir les quotas

```bash
kubectl get resourcequota -n devboard-dev
kubectl describe resourcequota devboard-quota -n devboard-dev
```

---

## 7. Health Checks

### 🏥 Liveness Probe

Vérifie si le container est vivant. Si échec → restart.

```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### ✅ Readiness Probe

Vérifie si le container est prêt à recevoir du trafic. Si échec → retiré du Service.

```yaml
readinessProbe:
  httpGet:
    path: /api/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

### 🚀 Startup Probe (optionnel)

Pour les apps avec démarrage lent.

```yaml
startupProbe:
  httpGet:
    path: /api/health
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  failureThreshold: 30  # 30 * 10s = 5 minutes max
```

---

## 8. HorizontalPodAutoscaler (HPA)

### 📈 Auto-scaling basé sur CPU

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: devboard-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: devboard-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**Comportement** :
- Si CPU > 70% → scale up (ajoute des pods)
- Si CPU < 70% → scale down (supprime des pods)
- Min 2 pods, max 10 pods

### 📊 Voir le status HPA

```bash
kubectl get hpa -n devboard-dev

# Résultat :
# NAME                    REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS
# devboard-backend-hpa    Deployment/backend       45%/70%   2         10        2
```

---

## 9. Commandes kubectl utiles

```bash
# Pods
kubectl get pods -n devboard-dev
kubectl describe pod <pod-name> -n devboard-dev
kubectl logs <pod-name> -n devboard-dev -f
kubectl exec -it <pod-name> -n devboard-dev -- /bin/sh

# Services
kubectl get svc -n devboard-dev
kubectl describe svc devboard-backend -n devboard-dev

# Ingress
kubectl get ingress -n devboard-dev
kubectl describe ingress devboard-ingress -n devboard-dev

# Deployments
kubectl get deploy -n devboard-dev
kubectl rollout status deployment devboard-backend -n devboard-dev
kubectl rollout restart deployment devboard-backend -n devboard-dev
kubectl rollout history deployment devboard-backend -n devboard-dev
kubectl rollout undo deployment devboard-backend -n devboard-dev

# Secrets
kubectl get secrets -n devboard-dev
kubectl describe secret devboard-secrets -n devboard-dev

# Events
kubectl get events -n devboard-dev --sort-by=.lastTimestamp

# Port-forward (pour tester)
kubectl port-forward svc/devboard-backend 8080:8080 -n devboard-dev

# Scale manuel
kubectl scale deployment devboard-backend --replicas=5 -n devboard-dev

# Delete all resources
kubectl delete all --all -n devboard-dev
```

---

## 10. Dépannage

### Pod en CrashLoopBackOff

```bash
# Voir les logs
kubectl logs <pod-name> -n devboard-dev --previous

# Voir les events
kubectl describe pod <pod-name> -n devboard-dev

# Cause fréquente : liveness probe échoue trop tôt
# Solution : augmenter initialDelaySeconds
```

### Image pull errors

```bash
# Vérifier l'image
kubectl describe pod <pod-name> -n devboard-dev | grep -A5 Events

# Si "ImagePullBackOff" :
# - Vérifier le tag de l'image
# - Vérifier imagePullPolicy (Never pour images locales)
# - Vérifier que l'image existe dans le registry
```

### Service pas accessible

```bash
# Vérifier que les pods sont Ready
kubectl get pods -n devboard-dev

# Vérifier le service
kubectl get svc devboard-backend -n devboard-dev

# Vérifier les endpoints
kubectl get endpoints devboard-backend -n devboard-dev

# Test direct vers un pod
kubectl port-forward <pod-name> 8080:8080 -n devboard-dev
curl http://localhost:8080/api/health
```

---

## 📚 Références

- [Helm Documentation](https://helm.sh/docs/)
- [Kustomize Guide](https://kustomize.io/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Health Checks](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
