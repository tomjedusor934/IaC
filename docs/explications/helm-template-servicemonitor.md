# Explication : `helm/fastapi-app/templates/servicemonitor.yaml`

Ce template crée un **ServiceMonitor** — un objet qui dit à Prometheus quoi scraper.

---

## Qu'est-ce qu'un ServiceMonitor ?

Prometheus collecte des métriques en **scrapant** des endpoints HTTP. Mais comment sait-il quels endpoints scraper ? Via les ServiceMonitors !

Un ServiceMonitor est un objet Kubernetes (Custom Resource) créé par le chart kube-prometheus-stack. Il dit à Prometheus :
> "Scrape le endpoint `/metrics` du Service X, toutes les 30 secondes"

---

## Contenu

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
```
- `monitoring.coreos.com/v1` : API du Prometheus Operator (installé via kube-prometheus-stack)
- `ServiceMonitor` : un Custom Resource (pas un objet Kubernetes natif)

```yaml
metadata:
  name: {{ include "fastapi-app.fullname" . }}
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
```
Nom et labels standard.

```yaml
spec:
  selector:
    matchLabels:
      {{- include "fastapi-app.selectorLabels" . | nindent 6 }}
```
Le **sélecteur** identifie le Service à scraper (par ses labels).

```yaml
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```
- `port: http` : le port nommé "http" du Service (port 80 → targetPort 8000)
- `path: /metrics` : l'endpoint où FastAPI expose ses métriques Prometheus
- `interval: 30s` : scrape toutes les 30 secondes

---

## Quelles métriques sont exposées ?

L'application FastAPI expose typiquement (via la librairie `prometheus-fastapi-instrumentator` ou similaire) :
- `http_requests_total` : nombre total de requêtes
- `http_request_duration_seconds` : durée des requêtes (histogramme)
- `http_requests_in_progress` : requêtes en cours
- Métriques Python (GC, threads, etc.)

---

## Le flux de données

```
FastAPI expose /metrics → Service route le trafic → ServiceMonitor dit à Prometheus de scraper
→ Prometheus stocke les métriques → Grafana les affiche en graphiques
```

---

## Pourquoi ce fichier est nécessaire ?

Sans ServiceMonitor, Prometheus **ne saurait pas** que l'application existe et n'en collecterait aucune métrique. C'est le lien entre l'application et le système de monitoring.

> Rappel : dans les fichiers monitoring-values, on a mis `serviceMonitorSelectorNilUsesHelmValues: false` pour que Prometheus scrape TOUS les ServiceMonitors, y compris celui-ci.
