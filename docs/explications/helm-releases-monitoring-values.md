# Explication : `terraform/helm-releases/monitoring-values-*.yaml`

Ces fichiers configurent la **stack de monitoring** (Prometheus + Grafana + Alertmanager) pour chaque environnement.

---

## Qu'est-ce que kube-prometheus-stack ?

C'est un chart Helm "tout-en-un" qui installe :
- **Prometheus** : collecte les métriques de tous les pods, nœuds et services
- **Grafana** : interface web pour visualiser les métriques sous forme de graphiques
- **Alertmanager** : envoie des notifications quand quelque chose ne va pas
- **kube-state-metrics** : expose les métriques de l'état des objets Kubernetes
- **node-exporter** : expose les métriques des machines (CPU, RAM, disque)

---

## `monitoring-values-dev.yaml`

### Prometheus

```yaml
prometheus:
  prometheusSpec:
    retention: 7d
```
Conservation des métriques pendant **7 jours** seulement. En dev, pas besoin d'historique long.

```yaml
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 10Gi
```
**10 Go de stockage** pour les métriques. Un PersistentVolumeClaim (PVC) est créé automatiquement.

```yaml
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
```
Limites de ressources de Prometheus. En dev, c'est réduit :
- `200m` CPU = 0.2 cœur demandé (requests)
- `512Mi` = 512 Mo de RAM demandés
- Les `limits` sont le maximum autorisé

```yaml
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
```
**Important** : permet à Prometheus de scraper TOUS les ServiceMonitors et PodMonitors, pas seulement ceux créés par le chart. Sans ça, le ServiceMonitor de notre app FastAPI serait ignoré.

### Grafana

```yaml
grafana:
  enabled: true
  adminPassword: "admin"   # À changer en production !
```
Grafana activé avec le mot de passe admin par défaut. **OK pour le dev**, pas pour la prod.

```yaml
  persistence:
    enabled: true
    size: 5Gi
```
Les dashboards et configs Grafana sont persistés sur disque (5 Go).

```yaml
  dashboardProviders:
    dashboardproviders.yaml:
      providers:
        - name: "custom"
          folder: "Custom"
          options:
            path: /var/lib/grafana/dashboards/custom
```
Configure un fournisseur de dashboards custom. Les dashboards dans le dossier `/var/lib/grafana/dashboards/custom` seront automatiquement importés.

### Alertmanager

```yaml
alertmanager:
  enabled: true
  alertmanagerSpec:
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
```
Alertmanager activé avec des ressources minimales en dev.

### Règles d'alerte par défaut

```yaml
defaultRules:
  create: true
  rules:
    alertmanager: true
    etcd: false           # Pas accessible sur GKE managé
    kubeControllerManager: false  # Pas accessible sur GKE managé
    kubeProxy: false      # Pas accessible sur GKE managé
    kubeScheduler: false  # Pas accessible sur GKE managé
```
Les règles par défaut créent des alertes pour les composants Kubernetes standards. On désactive celles des composants **managés par GKE** (etcd, controller manager, proxy, scheduler) car on n'y a pas accès.

---

## `monitoring-values-prd.yaml` — Différences avec le dev

| Paramètre | Dev | Prd |
|-----------|-----|-----|
| `retention` | 7d | **30d** |
| `storage` | 10Gi | **50Gi** |
| Prometheus CPU requests | 200m | **500m** |
| Prometheus memory requests | 512Mi | **1Gi** |
| Prometheus `replicas` | 1 (défaut) | **2** |
| Grafana password | `admin` | **placeholder sécurisé** |
| Grafana storage | 5Gi | **10Gi** |
| Alertmanager `replicas` | 1 (défaut) | **2** |

Points clés en production :
- **30 jours** de rétention des métriques (pour les analyses et les post-mortems)
- **Réplicas doublés** : 2 Prometheus et 2 Alertmanager pour la haute disponibilité
- **Plus de ressources** : la prod génère plus de métriques
- **Mot de passe sécurisé** : le mot de passe Grafana admin est un placeholder à remplacer

---

## Pourquoi ces fichiers sont nécessaires ?

Sans configuration personnalisée, kube-prometheus-stack s'installe avec des valeurs par défaut qui ne conviennent pas :
- Pas de stockage persistant → les métriques sont perdues au redémarrage
- Pas assez de ressources → Prometheus crash sous la charge
- Un seul réplica → interruption si le pod redémarre
- Tous les ServiceMonitors ne sont pas scrapés → métriques manquantes
