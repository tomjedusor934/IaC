# Explication : `helm/fastapi-app/templates/configmap.yaml`

Ce template crée un **ConfigMap** — un objet Kubernetes pour stocker des variables de configuration non-sensibles.

---

## Qu'est-ce qu'un ConfigMap ?

Un ConfigMap est comme un fichier `.env` dans Kubernetes. Il stocke des paires clé-valeur qui sont injectées comme **variables d'environnement** dans les containers.

La différence avec un Secret : un ConfigMap n'est **pas chiffré**. On y met uniquement des données non-sensibles.

---

## Contenu

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "fastapi-app.fullname" . }}-config
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
```
Le nom sera quelque chose comme `fastapi-app-fastapi-app-config`.

```yaml
data:
  {{- range $key, $value := .Values.env }}
  {{- if not (has $key (list "DATABASE_PASSWORD" "JWT_SECRET_KEY")) }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
  {{- end }}
```
**Logique importante** :
1. Parcourt toutes les variables dans `.Values.env`
2. **Exclut** `DATABASE_PASSWORD` et `JWT_SECRET_KEY` (qui sont sensibles)
3. Met les autres dans le ConfigMap

Variables incluses dans le ConfigMap :
- `ENVIRONMENT` : "dev" ou "prd"
- `LOG_LEVEL` : "DEBUG", "INFO" ou "WARNING"
- `DATABASE_HOST` : "127.0.0.1" (proxy localhost)
- `DATABASE_PORT` : "5432"
- `DATABASE_NAME` : "taskmanager"
- `DATABASE_USER` : "taskmanager"
- `RATE_LIMIT` : "100/minute" ou "200/minute"

Variables **exclues** (vont dans le Secret) :
- `DATABASE_PASSWORD`
- `JWT_SECRET_KEY`

---

## Comment le Deployment l'utilise

Dans le deployment.yaml :
```yaml
envFrom:
  - configMapRef:
      name: fastapi-app-fastapi-app-config
```
Toutes les clés du ConfigMap deviennent des variables d'environnement dans le container.

---

## Pourquoi ce fichier est nécessaire ?

Il sépare la **configuration** du **code**. L'application FastAPI lit ses paramètres via `os.environ["DATABASE_HOST"]` au lieu de les coder en dur. On peut changer la config sans reconstruire l'image Docker.

La séparation ConfigMap / Secret est une bonne pratique de sécurité : les ConfigMaps sont visibles par plus de personnes, les Secrets sont plus protégés.
