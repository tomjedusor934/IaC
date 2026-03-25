# Explication : `helm/fastapi-app/templates/deployment.yaml`

C'est le **fichier le plus important** du chart. Il définit comment l'application est déployée sur Kubernetes.

---

## Qu'est-ce qu'un Deployment ?

Un Deployment est un objet Kubernetes qui :
1. Crée et maintient des **Pods** (conteneurs)
2. Gère les **rolling updates** (mise à jour sans interruption)
3. Redémarre automatiquement les pods qui crashent
4. Scale le nombre de pods (avec le HPA)

---

## Explication ligne par ligne

### Métadonnées

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "fastapi-app.fullname" . }}
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
```
- `apiVersion: apps/v1` : version de l'API Kubernetes pour les Deployments
- Le nom et les labels viennent de `_helpers.tpl`

### Spec du Deployment

```yaml
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
```
Si le HPA est activé, on **ne spécifie pas** `replicas` (le HPA gère le nombre). Sinon on utilise `replicaCount`.

```yaml
  selector:
    matchLabels:
      {{- include "fastapi-app.selectorLabels" . | nindent 6 }}
```
Le sélecteur indique au Deployment quels pods il gère (ceux avec les bons labels).

### Template du Pod

```yaml
  template:
    metadata:
      labels:
        {{- include "fastapi-app.selectorLabels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include ... "/configmap.yaml" ... | sha256sum }}
        checksum/secret: {{ include ... "/secret.yaml" ... | sha256sum }}
```
**Astuce importante** : les annotations `checksum/config` et `checksum/secret` contiennent le **hash SHA-256** du ConfigMap et du Secret. Si on modifie une variable d'environnement, le hash change → le Deployment redémarre les pods. Sans ça, les pods ne redémarreraient pas et garderaient les anciennes valeurs.

### Spec du Pod

```yaml
    spec:
      serviceAccountName: {{ include "fastapi-app.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      nodeSelector:
        {{- toYaml .Values.nodeSelector | nindent 8 }}
```
- `serviceAccountName` : le SA Kubernetes lié au SA GCP via Workload Identity
- `securityContext` : les paramètres de sécurité (runAsNonRoot, etc.)
- `nodeSelector` : force les pods sur le node pool `app-pool`

### Le container FastAPI

```yaml
      containers:
        - name: fastapi
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
```
Le container principal qui fait tourner l'application FastAPI sur le port 8000.

```yaml
          envFrom:
            - configMapRef:
                name: {{ include "fastapi-app.fullname" . }}-config
            - secretRef:
                name: {{ include "fastapi-app.fullname" . }}-secret
```
Les variables d'environnement sont injectées depuis :
- Le **ConfigMap** : variables non-sensibles (ENVIRONMENT, LOG_LEVEL, etc.)
- Le **Secret** : variables sensibles (DATABASE_PASSWORD, JWT_SECRET_KEY)

```yaml
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 10
            periodSeconds: 15
            failureThreshold: 3
```
**Liveness probe** : Kubernetes vérifie toutes les 15 secondes que l'app répond sur `/healthz`. Après 3 échecs consécutifs → le pod est **tué et redémarré**.

```yaml
          readinessProbe:
            httpGet:
              path: /readyz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 3
```
**Readiness probe** : vérifie que l'app est prête à recevoir du trafic. Si elle échoue → le pod est **retiré du Service** (plus de trafic) mais pas tué.

```yaml
          volumeMounts:
            - name: tmp
              mountPath: /tmp
```
Monte un volume `tmp` car le filesystem racine est en lecture seule (`readOnlyRootFilesystem: true`). L'application a besoin d'un dossier temporaire.

### Le sidecar Cloud SQL Auth Proxy

```yaml
        {{- if .Values.cloudSqlProxy.enabled }}
        - name: cloud-sql-proxy
          image: {{ .Values.cloudSqlProxy.image }}
          args:
            - "--structured-logs"
            - "--auto-iam-authn"
            - "--port=5432"
            - "{{ .Values.cloudSqlProxy.instanceConnectionName }}"
```
Le **sidecar** Cloud SQL Auth Proxy :
- Tourne dans le **même pod** que FastAPI
- FastAPI se connecte à `127.0.0.1:5432` (localhost)
- Le proxy traduit ça en connexion sécurisée vers Cloud SQL
- `--auto-iam-authn` : utilise Workload Identity pour s'authentifier (pas de mot de passe)

### Volumes

```yaml
      volumes:
        - name: tmp
          emptyDir: {}
```
Un volume `emptyDir` : un dossier temporaire vide créé quand le pod démarre et supprimé quand il s'arrête.

---

## Pourquoi ce fichier est nécessaire ?

C'est lui qui **crée les pods** de l'application. Sans Deployment, il n'y a pas d'application qui tourne. Il gère :
- Le déploiement de l'image Docker
- L'injection des variables d'environnement
- La connexion à Cloud SQL via le proxy
- Les health checks
- La sécurité des containers
- Le placement sur les bons nœuds
