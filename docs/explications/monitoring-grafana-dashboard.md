# Explication : `monitoring/dashboards/fastapi-app-dashboard.json`

Ce fichier est un **dashboard Grafana** au format JSON pour visualiser les métriques de l'application.

---

## Qu'est-ce qu'un dashboard Grafana ?

Grafana est une interface web qui affiche des **graphiques** et **statistiques** à partir des métriques collectées par Prometheus. Un dashboard est un ensemble de "panneaux" (panels) organisés en grille.

Ce fichier JSON définit la disposition et les requêtes PromQL de chaque panneau.

---

## Les panneaux du dashboard

### 1. Request Rate (req/s)

```json
"expr": "sum(rate(http_requests_total{namespace=\"app\"}[5m])) by (method)"
```
- **Type** : graphique temporel (timeseries)
- **Ce qu'il montre** : le nombre de requêtes par seconde, groupé par méthode HTTP (GET, POST, PUT, DELETE)
- **Unité** : `reqps` (requêtes par seconde)

### 2. Error Rate (5xx)

```json
"expr": "sum(rate(http_requests_total{namespace=\"app\", status=~\"5..\"}[5m]))"
```
- **Type** : graphique temporel en rouge
- **Ce qu'il montre** : le nombre d'erreurs 5xx par seconde
- **Pourquoi** : un pic d'erreurs 5xx indique un problème côté serveur

### 3. Response Latency (P50 / P95 / P99)

```json
"expr": "histogram_quantile(0.50, ...)"  // P50 - latence médiane
"expr": "histogram_quantile(0.95, ...)"  // P95 - 95% des requêtes sont en dessous
"expr": "histogram_quantile(0.99, ...)"  // P99 - 99% des requêtes sont en dessous
```
- **Type** : graphique temporel sur toute la largeur
- **Ce qu'il montre** : la distribution de la latence des requêtes
- **Unité** : secondes
- **Les 3 percentiles** :
  - **P50** : la moitié des requêtes sont plus rapides que cette valeur
  - **P95** : 95% des requêtes sont plus rapides → les 5% les plus lentes
  - **P99** : 99% → les 1% les plus lentes (cas extrêmes)

### 4. HTTP Status Codes

```json
"expr": "sum(increase(http_requests_total{namespace=\"app\"}[1h])) by (status)"
```
- **Type** : camembert (piechart)
- **Ce qu'il montre** : la répartition des codes HTTP (200, 201, 400, 404, 500, etc.) sur la dernière heure
- **Pourquoi** : permet de voir rapidement si la majorité des requêtes réussissent

### 5. Active Replicas

```json
"expr": "kube_deployment_status_replicas{namespace=\"app\", deployment=~\".*fastapi.*\"}"
```
- **Type** : statistique (un nombre)
- **Ce qu'il montre** : combien de pods sont actifs en ce moment
- **Pourquoi** : permet de vérifier que l'autoscaling fonctionne

### 6. Pod CPU Usage

```json
"expr": "sum(rate(container_cpu_usage_seconds_total{namespace=\"app\", container=\"fastapi\"}[5m])) by (pod)"
```
- **Type** : graphique temporel
- **Ce qu'il montre** : la consommation CPU de chaque pod, groupée par nom de pod
- **Pourquoi** : détecter les pods qui consomment trop de CPU

### 7. Pod Memory Usage

```json
"expr": "sum(container_memory_working_set_bytes{namespace=\"app\", container=\"fastapi\"}) by (pod)"
```
- **Type** : graphique temporel
- **Ce qu'il montre** : la mémoire utilisée par chaque pod
- **Unité** : bytes (affiché en Mo/Go par Grafana)

### 8. Requests In Progress

```json
"expr": "sum(http_requests_inprogress{namespace=\"app\"})"
```
- **Type** : graphique temporel
- **Ce qu'il montre** : le nombre de requêtes en cours de traitement à chaque instant
- **Pourquoi** : un nombre qui augmente sans redescendre indique un blocage

---

## Structure du JSON

```json
{
  "title": "FastAPI Task Manager",
  "uid": "fastapi-task-manager",
  "schemaVersion": 39,
  "tags": ["fastapi", "task-manager", "application"],
  "time": { "from": "now-1h", "to": "now" },
  "panels": [ ... ]
}
```
- `uid` : identifiant unique du dashboard (pour les liens et l'API)
- `time` : période affichée par défaut (dernière heure)
- `tags` : pour filtrer les dashboards dans Grafana

Chaque panneau a un `gridPos` qui définit sa position :
- `h` : hauteur
- `w` : largeur (max 24 colonnes)
- `x`, `y` : position en haut à gauche

---

## Pourquoi ce fichier est nécessaire ?

Sans dashboard, tu aurais les métriques dans Prometheus mais aucun moyen de les **visualiser** facilement. Ce dashboard donne une vue d'ensemble instantanée de la santé de l'application :
- Est-ce qu'il y a des erreurs ?
- Les requêtes sont-elles rapides ?
- Combien de pods tournent ?
- Les ressources sont-elles bien utilisées ?
