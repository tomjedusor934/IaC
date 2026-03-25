# Explication : `helm/fastapi-app/Chart.yaml`

Le fichier d'identité du chart Helm.

---

## Qu'est-ce qu'un chart Helm ?

Helm est le **gestionnaire de packages** de Kubernetes. Un chart Helm est un ensemble de fichiers YAML qui décrivent comment déployer une application sur Kubernetes. C'est l'équivalent d'un `package.json` pour npm ou d'un `requirements.txt` pour Python.

## Contenu

```yaml
apiVersion: v2
```
Version de l'API Helm. `v2` est le format actuel (Helm 3).

```yaml
name: fastapi-app
```
Le nom du chart. Utilisé pour identifier le package.

```yaml
description: Helm chart for the FastAPI Task Manager application
```
Description humainement lisible.

```yaml
type: application
```
Type du chart :
- `application` : déploie une application (notre cas)
- `library` : fournit des fonctions réutilisables par d'autres charts

```yaml
version: 1.0.0
```
La version du **chart** lui-même. Pas de l'application.

```yaml
appVersion: "1.0.0"
```
La version de l'**application** déployée. Informatif seulement. La vraie version est le tag de l'image Docker.

```yaml
maintainers:
  - name: taskmanager-team
```
Qui maintient ce chart.

---

## Pourquoi ce fichier est nécessaire ?

Helm exige un `Chart.yaml` dans chaque chart. C'est le fichier minimum obligatoire. Sans lui, Helm ne reconnaît pas le dossier comme un chart.
