# Explication : `helm/fastapi-app/templates/_helpers.tpl`

Ce fichier contient des **fonctions réutilisables** (appelées "partials" ou "named templates") utilisées par tous les autres templates.

---

## Qu'est-ce qu'un fichier `_helpers.tpl` ?

Le `_` au début du nom signifie que Helm **ne le traite pas comme un manifest Kubernetes**. Il ne génère aucune ressource. Il sert uniquement de bibliothèque de fonctions.

---

## Les fonctions définies

### `fastapi-app.labels` — Labels communs

```
{{- define "fastapi-app.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
```
Génère un ensemble de **labels standards** appliqués à toutes les ressources Kubernetes :
- `app.kubernetes.io/name` : nom du chart (`fastapi-app`)
- `app.kubernetes.io/instance` : nom de la release Helm
- `app.kubernetes.io/version` : version de l'application
- `app.kubernetes.io/managed-by` : `Helm`
- `helm.sh/chart` : nom et version du chart

Ces labels permettent de **filtrer** et **identifier** les ressources dans le cluster.

### `fastapi-app.selectorLabels` — Labels de sélection

```
{{- define "fastapi-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```
Un sous-ensemble des labels utilisé par les **sélecteurs** (Service → Pods, Deployment → Pods). On n'inclut que le nom et l'instance car les labels de version changent entre les releases.

> Si on incluait la version dans le sélecteur, un rolling update casserait car les nouveaux pods auraient une version différente.

### `fastapi-app.fullname` — Nom complet

```
{{- define "fastapi-app.fullname" -}}
{{- if .Values.fullnameOverride }}
  ...
{{- else }}
  {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
```
Génère le nom complet de la ressource (ex: `fastapi-app-fastapi-app`). `trunc 63` : les noms Kubernetes sont limités à 63 caractères.

### `fastapi-app.serviceAccountName` — Nom du ServiceAccount

```
{{- define "fastapi-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
  {{- default (include "fastapi-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
  {{- default "default" .Values.serviceAccount.name }}
{{- end }}
```
Si `serviceAccount.create = true` et qu'un nom est spécifié → utilise ce nom. Sinon → utilise le fullname.

---

## Pourquoi ce fichier est nécessaire ?

Sans lui, il faudrait **copier-coller** les mêmes labels et noms dans chaque template. Avec `_helpers.tpl`, on les définit une seule fois et on les inclut partout avec `{{ include "fastapi-app.labels" . }}`. C'est le principe DRY.
