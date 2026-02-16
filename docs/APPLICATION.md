# Application DevBoard - Documentation technique

## Vue d'ensemble

**DevBoard** est une plateforme de gestion de projets ESN (Entreprise de Services du Numérique) composée de :
- **Backend** : API REST en Go (Gin framework)
- **Frontend** : Interface React + Vite
- **Base de données** : PostgreSQL 16

---

## Architecture de l'application

```
┌──────────────────────────────────────────────────────┐
│                    Frontend React                     │
│                   (Port 80 - Nginx)                   │
│                                                       │
│  - Dashboard avec statistiques                        │
│  - Liste et gestion des projets                       │
│  - Formulaire de création/édition                     │
│  - Interface responsive                               │
└───────────────────┬──────────────────────────────────┘
                    │ HTTP/REST
                    │ /api/*
┌───────────────────▼──────────────────────────────────┐
│                  Backend Go (Gin)                     │
│                   (Port 8080)                         │
│                                                       │
│  - API REST CRUD projets                              │
│  - Endpoints /health, /ready, /metrics                │
│  - Middleware de logging et métriques                 │
│  - Validation des données                             │
└───────────────────┬──────────────────────────────────┘
                    │ SQL
                    │ PostgreSQL wire protocol
┌───────────────────▼──────────────────────────────────┐
│                PostgreSQL 16 Alpine                   │
│                   (Port 5432)                         │
│                                                       │
│  - Base de données relationnelle                      │
│  - Persistance sur PVC 1Gi (K8s)                      │
│  - Credentials via Vault                              │
└──────────────────────────────────────────────────────┘
```

---

## 1. Backend Go (Gin)

### 📁 Emplacement
`app/backend/`

### 🏗️ Structure

```
app/backend/
├── cmd/
│   └── server/
│       └── main.go           # Point d'entrée
├── internal/
│   ├── api/
│   │   ├── handlers/         # Handlers HTTP
│   │   │   ├── health.go
│   │   │   ├── projects.go
│   │   │   └── metrics.go
│   │   └── middleware/       # Middlewares
│   │       ├── logger.go
│   │       └── metrics.go
│   ├── models/
│   │   └── project.go        # Modèle de données
│   └── repository/
│       └── postgres.go       # Accès BDD
├── Dockerfile                # Image multi-stage (~4Mo)
├── go.mod                    # Dépendances Go
└── go.sum                    # Checksums dépendances
```

### 🎯 Endpoints API

| Méthode | Endpoint            | Description                    | Réponse           |
|---------|---------------------|--------------------------------|-------------------|
| GET     | `/api/health`       | Health check                   | `{"status":"ok"}` |
| GET     | `/api/ready`        | Readiness check (BDD)          | `{"status":"ready"}` |
| GET     | `/api/metrics`      | Métriques Prometheus           | Format Prometheus |
| GET     | `/api/projects`     | Liste tous les projets         | JSON array        |
| GET     | `/api/projects/:id` | Détail d'un projet             | JSON object       |
| POST    | `/api/projects`     | Créer un nouveau projet        | JSON object       |
| PUT     | `/api/projects/:id` | Modifier un projet             | JSON object       |
| DELETE  | `/api/projects/:id` | Supprimer un projet            | 204 No Content    |

### 📊 Modèle de données : Project

```go
type Project struct {
    ID          int       `json:"id" db:"id"`
    Name        string    `json:"name" db:"name" binding:"required"`
    Description string    `json:"description" db:"description"`
    Status      string    `json:"status" db:"status" binding:"required,oneof=planned active completed"`
    StartDate   time.Time `json:"start_date" db:"start_date"`
    EndDate     time.Time `json:"end_date" db:"end_date"`
    Budget      float64   `json:"budget" db:"budget"`
    ClientName  string    `json:"client_name" db:"client_name"`
    CreatedAt   time.Time `json:"created_at" db:"created_at"`
    UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}
```

### 🔧 Dépendances (go.mod)

```go
require (
    github.com/gin-gonic/gin v1.9.1              // Framework HTTP
    github.com/lib/pq v1.10.9                    // Driver PostgreSQL
    github.com/prometheus/client_golang v1.19.0  // Métriques Prometheus
    github.com/stretchr/testify v1.8.3           // Tests
)
```

### 📈 Métriques exposées

Le backend expose des métriques Prometheus sur `/api/metrics` :

```prometheus
# Requêtes HTTP totales
http_requests_total{method="GET",endpoint="/api/projects",status="200"}

# Durée des requêtes HTTP (histogramme)
http_request_duration_seconds{method="GET",endpoint="/api/projects"}

# Requêtes en cours
http_requests_in_progress{method="GET",endpoint="/api/projects"}

# Métriques Go standards
go_goroutines
go_memstats_alloc_bytes
```

### 🐳 Dockerfile

```dockerfile
# Stage 1: Build
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o server ./cmd/server

# Stage 2: Run (~4 Mo final)
FROM scratch
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

**Optimisations** :
- Multi-stage build : image finale ~4Mo
- Base `scratch` : image minimale (seulement le binaire)
- Compilation statique (`CGO_ENABLED=0`)

### 🚀 Lancer en local

```bash
# Avec Docker Compose
cd /home/tom/Dev/projet-etude
docker-compose up backend

# Directement avec Go
cd app/backend
export DATABASE_URL="postgres://user:pass@localhost:5432/devboard?sslmode=disable"
go run cmd/server/main.go
```

### 🧪 Tests

```bash
cd app/backend
go test ./...
```

### 🔍 Variables d'environnement

| Variable       | Description                | Défaut                     | Requis |
|----------------|----------------------------|----------------------------|--------|
| `DATABASE_URL` | URL de connexion PostgreSQL| -                          | ✅     |
| `PORT`         | Port d'écoute              | 8080                       | ❌     |
| `GIN_MODE`     | Mode Gin (debug/release)   | release                    | ❌     |

---

## 2. Frontend React (Vite)

### 📁 Emplacement
`app/frontend/`

### 🏗️ Structure

```
app/frontend/
├── src/
│   ├── components/
│   │   ├── Dashboard.jsx     # Composant principal
│   │   ├── ProjectList.jsx   # Liste des projets
│   │   ├── ProjectForm.jsx   # Formulaire création/édition
│   │   └── Stats.jsx         # Statistiques
│   ├── services/
│   │   └── api.js            # Client API (axios)
│   ├── App.jsx               # Composant racine
│   └── main.jsx              # Point d'entrée
├── public/
├── index.html
├── vite.config.js            # Configuration Vite
├── package.json              # Dépendances npm
├── nginx.conf                # Configuration Nginx
└── Dockerfile                # Image multi-stage (~25Mo)
```

### 🎨 Stack technique

- **Framework** : React 18
- **Build tool** : Vite (remplacement de CRA, plus rapide)
- **HTTP Client** : Axios
- **Serveur web** : Nginx Alpine (en production)

### 📦 Dépendances (package.json)

```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.0.0"
  }
}
```

### 🖥️ Composants principaux

#### Dashboard.jsx
Point d'entrée principal :
- Affiche les stats (nombre de projets, budget total)
- Contient la liste des projets
- Gère l'état global de l'application

#### ProjectList.jsx
Liste des projets avec :
- Table responsive
- Actions : Éditer, Supprimer
- Filtrage par statut (planned, active, completed)
- Badges colorés pour les statuts

#### ProjectForm.jsx
Formulaire de création/édition :
- Validation côté client
- Gestion des dates (DatePicker)
- Gestion des erreurs API

#### Stats.jsx
Composant de statistiques :
- Nombre total de projets
- Projets actifs
- Budget total
- Cartes avec icônes

### 🌐 Configuration Nginx (nginx.conf)

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # Proxy API vers le backend
    location /api/ {
        proxy_pass http://${BACKEND_HOST}:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # SPA : toutes les routes vers index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

**Note** : `${BACKEND_HOST}` est résolu dynamiquement via `envsubst` au démarrage du container.

### 🐳 Dockerfile

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Serve (~25 Mo)
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/templates/default.conf.template
ENV BACKEND_HOST=backend
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**Optimisations** :
- Multi-stage build
- Nginx templates pour config dynamique
- Compression gzip automatique (nginx)

### 🚀 Lancer en local

```bash
# Mode développement avec hot reload
cd app/frontend
npm install
npm run dev
# Accès : http://localhost:5173

# Build de production
npm run build
# Fichiers dans dist/

# Avec Docker Compose
cd /home/tom/Dev/projet-etude
docker-compose up frontend
```

### 🔍 Variables d'environnement

| Variable        | Description                    | Défaut    | Usage         |
|-----------------|--------------------------------|-----------|---------------|
| `BACKEND_HOST`  | Hostname du backend            | backend   | Nginx (prod)  |
| `VITE_API_URL`  | URL de l'API (dev uniquement)  | /api      | Dev Vite      |

---

## 3. Base de données PostgreSQL

### 🎯 Configuration

- **Image** : `postgres:16-alpine`
- **Port** : 5432
- **Persistance** : PVC 1Gi (Kubernetes)
- **Credentials** : Stockés dans Vault

### 📊 Schéma de base de données

```sql
-- Table projects
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL CHECK (status IN ('planned', 'active', 'completed')),
    start_date DATE,
    end_date DATE,
    budget DECIMAL(15, 2),
    client_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index pour optimiser les requêtes
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_created_at ON projects(created_at DESC);
```

### 🔒 Sécurité

Les credentials sont stockés dans **Vault** :

```bash
# Lire les secrets depuis Vault
export VAULT_ADDR=http://vault.devboard.local
export VAULT_TOKEN=root
vault kv get secret/devboard/db

# Résultat :
# username: devboard
# password: devboard-secret
# host: postgres
# port: 5432
# database: devboard
```

### 🚀 Initialisation

Le schéma est créé automatiquement au démarrage du backend (migrations intégrées).

Ou manuellement :

```bash
# Connexion à PostgreSQL
kubectl exec -n devboard-dev -it devboard-postgres-<pod-id> -- psql -U devboard

# Créer la table
CREATE TABLE projects (...);
```

---

## 4. Docker Compose (développement local)

### 📁 Fichier
`docker-compose.yml`

### 🎯 Services

```yaml
version: '3.8'
services:
  backend:
    build: ./app/backend
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://devboard:devboard@postgres:5432/devboard?sslmode=disable
    depends_on:
      - postgres

  frontend:
    build: ./app/frontend
    ports:
      - "80:80"
    environment:
      BACKEND_HOST: backend

  postgres:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: devboard
      POSTGRES_PASSWORD: devboard
      POSTGRES_DB: devboard
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
```

### 🚀 Commandes

```bash
# Démarrer tous les services
docker-compose up -d

# Démarrer un service spécifique
docker-compose up backend

# Voir les logs
docker-compose logs -f

# Arrêter
docker-compose down

# Rebuild après changement de code
docker-compose up --build
```

---

## 5. Déploiement sur Kubernetes

### 🎯 Déploiement via Helm

```bash
# Depuis ta machine locale
export KUBECONFIG=/home/tom/Dev/projet-etude/infra/ansible/kubeconfig.yaml

# Déployer en dev
helm upgrade --install devboard helm/devboard/ \
  -f helm/devboard/values-dev.yaml \
  -n devboard-dev

# Vérifier le déploiement
kubectl get pods -n devboard-dev
kubectl get svc -n devboard-dev
kubectl get ingress -n devboard-dev
```

### 📦 Ressources créées

- **3 Deployments** : backend, frontend, postgres
- **3 Services** : backend:8080, frontend:80, postgres:5432
- **1 Ingress** : dev.devboard.local → backend/frontend
- **1 PVC** : 1Gi pour PostgreSQL
- **1 Secret** : DB credentials et JWT secret

### 🌐 Accès

Après configuration `/etc/hosts` :
- **Frontend** : http://dev.devboard.local
- **Backend API** : http://dev.devboard.local/api/
- **Health** : http://dev.devboard.local/api/health

---

## 6. CI/CD

Voir [CI-CD.md](CI-CD.md) pour les détails du pipeline GitHub Actions.

---

## 7. Monitoring et observabilité

### 📊 Métriques Prometheus

Le backend expose des métriques sur `/api/metrics` :
- Nombre de requêtes HTTP
- Latence des requêtes (histogramme)
- Taux d'erreur
- Métriques Go (goroutines, memory)

**Configuration Prometheus** : scraping automatique via ServiceMonitor.

### 📝 Logs

Les logs sont collectés par **Promtail** et centralisés dans **Loki**.

Accès dans Grafana → Explore → Loki → `{namespace="devboard-dev"}`

### 🚨 Alertes

Voir `monitoring/prometheus/custom-rules.yml` :
- Backend down (replicas < expected)
- Taux d'erreur > 5%
- Latence P95 > 1s

---

## 8. Tests

### Backend (Go)

```bash
cd app/backend
go test ./...
go test -cover ./...
```

### Frontend (React)

```bash
cd app/frontend
npm test
```

**Note** : Tests à compléter (TODO dans ETAT-PROJET.md)

---

## 9. Dépannage

### Backend ne se connecte pas à la BDD

**Vérifier** :
1. PostgreSQL est running ?
   ```bash
   kubectl get pods -n devboard-dev | grep postgres
   ```
2. Secret existe ?
   ```bash
   kubectl get secret devboard-secrets -n devboard-dev
   ```
3. Logs du backend :
   ```bash
   kubectl logs -n devboard-dev <backend-pod> --tail=50
   ```

### Frontend ne charge pas

**Vérifier** :
1. Le pod est running ?
2. Nginx démarre correctement ?
   ```bash
   kubectl logs -n devboard-dev <frontend-pod>
   ```
3. Variable `BACKEND_HOST` est correcte ?
   ```bash
   kubectl describe pod <frontend-pod> -n devboard-dev | grep BACKEND_HOST
   ```

### Erreur CORS

**Cause** : Backend ne configure pas les headers CORS.

**Solution** : Ajouter middleware CORS dans Gin ou utiliser Ingress (déjà configuré).

---

## 10. Évolutions futures

- [ ] Authentification JWT
- [ ] Gestion des utilisateurs
- [ ] Upload de fichiers
- [ ] Notifications en temps réel (WebSocket)
- [ ] Tests E2E (Cypress/Playwright)
- [ ] Mode sombre (frontend)
- [ ] Export de rapports (PDF)
- [ ] API GraphQL (alternative REST)

---

## 📚 Références

- [Gin Framework](https://gin-gonic.com/docs/)
- [React Documentation](https://react.dev/)
- [Vite Guide](https://vitejs.dev/guide/)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
