# Explication : `helm/fastapi-app/templates/secret.yaml`

Ce template crée un **Secret Kubernetes** pour stocker les données sensibles.

---

## Qu'est-ce qu'un Secret ?

Un Secret est similaire à un ConfigMap, mais conçu pour les données **sensibles** (mots de passe, clés API, tokens). Les différences :
- Les Secrets sont encodés en **base64** (attention : ce n'est pas du chiffrement !)
- L'accès aux Secrets peut être restreint via RBAC
- Kubernetes peut être configuré pour **chiffrer** les Secrets au repos

---

## Contenu

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "fastapi-app.fullname" . }}-secret
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
type: Opaque
```
- `type: Opaque` : type générique (données arbitraires). D'autres types existent (`kubernetes.io/tls`, `kubernetes.io/dockerconfigjson`, etc.)

```yaml
stringData:
  DATABASE_PASSWORD: {{ .Values.env.DATABASE_PASSWORD | quote }}
  JWT_SECRET_KEY: {{ .Values.env.JWT_SECRET_KEY | quote }}
```
`stringData` accepte des valeurs **en clair** (Kubernetes les encode automatiquement en base64). Les deux secrets :
- `DATABASE_PASSWORD` : le mot de passe pour se connecter à Cloud SQL
- `JWT_SECRET_KEY` : la clé pour signer les tokens JWT d'authentification

> Ces valeurs sont vides dans `values.yaml` et injectées par Terraform via `set_sensitive` lors du déploiement.

---

## Comment le Deployment l'utilise

Dans le deployment.yaml :
```yaml
envFrom:
  - secretRef:
      name: fastapi-app-fastapi-app-secret
```
Les clés du Secret deviennent des variables d'environnement dans le container.

---

## Pourquoi ce fichier est nécessaire ?

Séparer les données sensibles des données non-sensibles est une **bonne pratique de sécurité** :
- Les admins qui voient les ConfigMaps ne voient pas forcément les Secrets
- On peut appliquer des politiques différentes (rotation, audit)
- Les outils de scan ne flagguent pas les ConfigMaps mais alertent sur les Secrets en clair
