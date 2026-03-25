# Explication : `helm/fastapi-app/templates/serviceaccount.yaml`

Ce template crée un **ServiceAccount Kubernetes** pour l'application.

---

## Qu'est-ce qu'un ServiceAccount ?

Un ServiceAccount est une **identité** pour les pods. Quand un pod fait une requête à l'API Kubernetes ou à un service externe (comme GCP), il s'identifie via son ServiceAccount.

Par défaut, tous les pods utilisent le ServiceAccount `default` du namespace. C'est un **anti-pattern de sécurité** car il a souvent trop de permissions.

---

## Contenu

```yaml
{{- if .Values.serviceAccount.create }}
```
Créé uniquement si `serviceAccount.create = true`.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "fastapi-app.serviceAccountName" . }}
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
```
Le nom est `fastapi-app` (défini dans values.yaml).

```yaml
  annotations:
    {{- toYaml .Values.serviceAccount.annotations | nindent 4 }}
```
Les **annotations** sont cruciales ici :
```yaml
iam.gke.io/gcp-service-account: "taskmanager-dev-app-sa@project.iam.gserviceaccount.com"
```
Cette annotation lie le ServiceAccount Kubernetes au **ServiceAccount GCP** via **GKE Workload Identity**. C'est ce qui permet aux pods d'accéder à Cloud SQL et Secret Manager sans clé JSON.

---

## La chaîne complète

```
Pod FastAPI
  → utilise le ServiceAccount K8s "fastapi-app"
    → annoté avec le SA GCP "taskmanager-dev-app-sa"
      → qui a les rôles "cloudsql.client" et "secretmanager.secretAccessor"
        → accès autorisé à Cloud SQL et Secret Manager
```

---

## Pourquoi ce fichier est nécessaire ?

C'est le **maillon essentiel** de la chaîne Workload Identity. Sans ce ServiceAccount avec l'annotation GCP :
- Les pods ne pourraient pas accéder à Cloud SQL
- Les pods ne pourraient pas lire les secrets dans Secret Manager
- Il faudrait monter des clés JSON dans les pods (anti-pattern)
