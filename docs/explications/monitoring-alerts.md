# Explication : `monitoring/alerts/fastapi-app-alerts.yaml`

Ce fichier définit les **règles d'alerte Prometheus** personnalisées pour l'application.

---

## Qu'est-ce qu'une PrometheusRule ?

C'est un Custom Resource (objet Kubernetes spécial) qui définit des règles d'alerte. Prometheus évalue ces règles périodiquement et, si une condition est remplie pendant une durée donnée, il déclenche une alerte via Alertmanager.

---

## Structure d'une alerte

```yaml
- alert: NomDeLAlerte
  expr: <requête PromQL>      # Condition
  for: 5m                      # Pendant combien de temps la condition doit être vraie
  labels:
    severity: warning/critical  # Gravité
  annotations:
    summary: "Résumé court"
    description: "Description détaillée"
```

---

## Groupe 1 : Alertes applicatives (`fastapi-app.rules`)

### HighErrorRate

```yaml
expr: (sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))) > 0.05
for: 2m
severity: critical
```
Se déclenche quand **plus de 5% des requêtes** retournent une erreur 5xx pendant 2 minutes.

Explication de la requête PromQL :
- `rate(http_requests_total{status=~"5.."}[5m])` : nombre de requêtes 5xx par seconde sur 5 min
- `/ sum(rate(http_requests_total[5m]))` : divisé par le total de requêtes
- `> 0.05` : supérieur à 5%

### HighLatencyP95

```yaml
expr: histogram_quantile(0.95, ...) > 1.0
for: 5m
severity: warning
```
Se déclenche quand la **latence au 95e percentile** dépasse 1 seconde pendant 5 minutes. Ça signifie que 5% des requêtes mettent plus de 1s.

### HighLatencyP99

```yaml
expr: histogram_quantile(0.99, ...) > 3.0
severity: critical
```
Latence au **99e percentile** > 3 secondes. Plus grave → severity `critical`.

### HighRequestRate

```yaml
expr: sum(rate(http_requests_total[1m])) > 500
severity: warning
```
Plus de **500 requêtes par seconde**. Peut indiquer un pic de trafic ou une attaque DDoS.

---

## Groupe 2 : Alertes de scaling (`scaling.rules`)

### PodCrashLooping

```yaml
expr: rate(kube_pod_container_status_restarts_total{namespace="app"}[15m]) > 0
for: 5m
severity: critical
```
Un pod dans le namespace `app` **redémarre en boucle** depuis plus de 5 minutes. Souvent causé par une erreur de configuration ou un bug.

### HPAMaxedOut

```yaml
expr: kube_horizontalpodautoscaler_status_current_replicas == kube_horizontalpodautoscaler_spec_max_replicas
for: 10m
severity: warning
```
Le HPA est au **maximum de réplicas** depuis 10 minutes. L'application ne peut plus scaler → il faut augmenter la limite ou optimiser l'application.

### PodNotReady

```yaml
expr: kube_pod_status_ready{namespace="app", condition="true"} == 0
for: 5m
severity: warning
```
Un pod n'est **pas prêt** depuis 5 minutes. Il est peut-être bloqué au démarrage ou la readiness probe échoue.

---

## Groupe 3 : Alertes runners (`runner.rules`)

### RunnerPoolMaxed / RunnerPodFailing

Alertes similaires pour les runners GitHub Actions self-hosted :
- Tous les runners sont occupés depuis 10 min
- Un runner est en état d'erreur

---

## Groupe 4 : Alertes infrastructure (`infrastructure.rules`)

### HighNodeCPU

```yaml
expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
severity: warning
```
Un **nœud** utilise plus de 85% de son CPU depuis 10 minutes. Il faut peut-être ajouter des nœuds ou augmenter les tailles de machines.

### HighNodeMemory

Même chose pour la mémoire > 85%.

### PersistentVolumeAlmostFull

```yaml
expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
severity: warning
```
Un **disque persistant** est rempli à plus de 85%. Peut toucher Prometheus (qui stocke les métriques) ou Grafana.

---

## Pourquoi ce fichier est nécessaire ?

Sans alertes, personne ne sait que quelque chose ne va pas avant que les utilisateurs se plaignent. Les alertes sont le **système d'alarme** de l'infrastructure. Elles détectent les problèmes avant qu'ils ne deviennent critiques :
- Erreurs applicatives → l'équipe corrige le bug
- Scaling maximal → on augmente les limites
- Nœuds surchargés → on scale le cluster
