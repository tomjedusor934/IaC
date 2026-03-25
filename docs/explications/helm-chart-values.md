# Explication : `helm/fastapi-app/values.yaml`

Le fichier de **valeurs par défaut** du chart Helm. C'est le cœur de la configuration.

---

## Qu'est-ce que `values.yaml` ?

Dans un chart Helm, les templates (dans `templates/`) contiennent des variables au format `{{ .Values.xx }}`. Le fichier `values.yaml` fournit les valeurs par défaut de ces variables. On peut les surcharger avec des fichiers spécifiques (`values-dev.yaml`, `values-prd.yaml`).

---

## Section par section

### Réplicas

```yaml
replicaCount: 1
```
Nombre de pods de l'application. 1 par défaut, surchargé à 3 en prod.

### Image Docker

```yaml
image:
  repository: "HERE_ARTIFACT_REGISTRY_URL/fastapi-app"
  tag: "latest"
  pullPolicy: IfNotPresent
```
- `repository` : l'URL complète de l'image (surchargée dynamiquement par Terraform)
- `tag` : la version de l'image (`latest` ou un SHA de commit)
- `pullPolicy: IfNotPresent` : ne re-télécharge l'image que si elle n'est pas déjà sur le nœud

### ServiceAccount

```yaml
serviceAccount:
  create: true
  name: "fastapi-app"
  annotations:
    iam.gke.io/gcp-service-account: "HERE_APP_SERVICE_ACCOUNT_EMAIL"
```
Crée un **ServiceAccount Kubernetes** nommé `fastapi-app`. L'annotation `iam.gke.io/gcp-service-account` lie ce SA au SA GCP via **Workload Identity** (surchargée par Terraform).

### Service

```yaml
service:
  type: ClusterIP
  port: 80
  targetPort: 8000
```
- `ClusterIP` : le service n'est accessible qu'**à l'intérieur** du cluster
- `port: 80` : le port exposé par le service
- `targetPort: 8000` : le port sur lequel FastAPI écoute dans le container

Le trafic externe passe par l'Ingress → Service → Pod(s).

### Ingress

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - host: "HERE_APP_DOMAIN"
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: fastapi-app-tls
      hosts:
        - "HERE_APP_DOMAIN"
```
L'**Ingress** expose l'application sur Internet :
- `className: nginx` : utilise le contrôleur NGINX installé via Helm
- `cert-manager.io/cluster-issuer` : demande automatiquement un certificat TLS via Let's Encrypt
- `ssl-redirect` : force HTTPS
- `tls` : configure le certificat TLS

### Autoscaling (HPA)

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```
Le **Horizontal Pod Autoscaler** ajuste automatiquement le nombre de pods :
- Si la CPU dépasse 70% → ajoute un pod
- Si la mémoire dépasse 80% → ajoute un pod
- Minimum 1 pod, maximum 5

### Resources

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```
- `requests` : ce que le pod **demande** au minimum (garanti)
- `limits` : ce que le pod peut utiliser **au maximum**

### Pod Disruption Budget (PDB)

```yaml
pdb:
  enabled: false
  minAvailable: 1
```
Le PDB empêche Kubernetes de supprimer trop de pods en même temps (lors d'un rolling update ou d'un drain de nœud). Désactivé par défaut, activé en prod.

### Cloud SQL Auth Proxy

```yaml
cloudSqlProxy:
  enabled: true
  instanceConnectionName: "HERE_CLOUDSQL_CONNECTION_NAME"
  image: "gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.13.0"
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
```
Le **Cloud SQL Auth Proxy** est un **sidecar container** (un container qui tourne dans le même pod que l'application). Il gère la connexion sécurisée à Cloud SQL :
- L'app se connecte à `127.0.0.1:5432` (localhost)
- Le proxy traduit ça en connexion sécurisée vers Cloud SQL
- Pas besoin de gérer les certificats SSL ou les IP

### Variables d'environnement

```yaml
env:
  ENVIRONMENT: "dev"
  LOG_LEVEL: "INFO"
  DATABASE_HOST: "127.0.0.1"
  DATABASE_PORT: "5432"
  DATABASE_NAME: "taskmanager"
  DATABASE_USER: "taskmanager"
  DATABASE_PASSWORD: ""
  JWT_SECRET_KEY: ""
  RATE_LIMIT: "100/minute"
```
Les variables d'environnement injectées dans le container. Notes :
- `DATABASE_HOST: "127.0.0.1"` : car le Cloud SQL Proxy tourne en sidecar
- `DATABASE_PASSWORD` et `JWT_SECRET_KEY` : vides ici, injectés par Terraform via `set_sensitive`

### Node Selector

```yaml
nodeSelector:
  cloud.google.com/gke-nodepool: "app-pool"
```
Force les pods à tourner sur le **app-pool** uniquement (pas sur le default-pool ou le runner-pool).

### Sécurité des pods

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
```
- `runAsNonRoot: true` : interdit de tourner en tant que root
- `runAsUser: 1000` : tourne sous l'utilisateur 1000 (non-privilégié)
- `seccompProfile: RuntimeDefault` : active le filtrage des appels système

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```
- `allowPrivilegeEscalation: false` : un processus ne peut pas devenir root
- `readOnlyRootFilesystem: true` : le filesystem est en lecture seule
- `drop: ALL` : supprime toutes les capabilities Linux

> Ces réglages de sécurité sont des **bonnes pratiques** pour réduire la surface d'attaque.

---

## Pourquoi ce fichier est nécessaire ?

C'est la **configuration centrale** de l'application. Il définit comment l'application est déployée sur Kubernetes : combien de réplicas, quelles ressources, comment accéder à la base de données, comment exposer l'app sur Internet, etc.
