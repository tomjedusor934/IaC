# Explication : `terraform/environments/prd/`

L'environnement de **production** (prd). La structure est **identique** à l'environnement dev, mais avec des paramètres adaptés à la production.

---

## Qu'est-ce qui change par rapport au dev ?

Ce fichier couvre les 5 fichiers de l'env prd. Voici les différences clés :

---

### `backend.tf` — Le state Terraform

```hcl
backend "gcs" {
  bucket = "HERE_GCS_STATE_BUCKET_NAME"
  prefix = "env/prd"   # ← "prd" au lieu de "dev"
}
```
Le **prefix est différent** (`env/prd` vs `env/dev`). Cela signifie que les states dev et prd sont **complètement séparés**. Modifier la prod ne touche pas au dev et vice-versa.

Les providers et versions sont identiques.

---

### `variables.tf` — Les variables

```hcl
variable "environment" {
  default = "prd"   # ← "prd" au lieu de "dev"
}
```
La seule différence : la valeur par défaut de `environment` est `"prd"`. Toutes les autres variables sont identiques.

---

### `terraform.tfvars` — Les valeurs concrètes

```hcl
project_id  = "HERE_GCP_PROJECT_ID_PRD"   # ← Projet GCP DIFFÉRENT
environment = "prd"
```
**Point important** : en production, on utilise souvent un **projet GCP séparé**. Cela isole complètement les ressources dev et prod.

---

### `main.tf` — L'orchestration (les différences clés)

#### GKE : cluster plus gros et plus résilient

| Paramètre | Dev | Prd |
|-----------|-----|-----|
| `release_channel` | `REGULAR` | `STABLE` |
| `deletion_protection` | `false` | `true` |
| `app_pool_machine_type` | `e2-standard-2` | `e2-standard-4` |
| `app_pool_min_count` | 1 | **2** |
| `app_pool_max_count` | 2 | **5** |
| `runner_pool_max_count` | 3 | **5** |

- **STABLE** : en prod, on veut les mises à jour les plus testées (pas les nouvelles fonctionnalités)
- **deletion_protection = true** : empêche la suppression accidentelle du cluster
- **Machines plus grosses** et **plus de nœuds** : la prod doit supporter plus de charge

#### Cloud SQL : haute disponibilité

| Paramètre | Dev | Prd |
|-----------|-----|-----|
| `db_tier` | `db-custom-1-3840` | `db-custom-2-8192` |
| `availability_type` | `ZONAL` | **`REGIONAL`** |
| `disk_size` | 10 | **20** |
| `deletion_protection` | `false` | `true` |

- **REGIONAL** : un réplica standby est créé dans une autre zone. Si la zone principale tombe, la base bascule automatiquement
- **Plus de CPU/RAM** : 2 vCPU et 8 Go au lieu de 1 vCPU et 3.75 Go

#### NGINX Ingress : haute disponibilité

```hcl
set {
  name  = "controller.replicaCount"
  value = "2"   # ← 2 réplicas au lieu de 1
}
```
En prod, on a **2 instances** du load balancer pour éviter les interruptions de service.

#### Prometheus/Grafana

```hcl
values = [
  file("${path.module}/../../helm-releases/monitoring-values-prd.yaml")
]
```
Utilise le fichier de configuration **prd** (plus de rétention, alertes différentes).

#### FastAPI App

```hcl
values = [
  file("${path.module}/../../../helm/fastapi-app/values-prd.yaml")
]
```
Utilise les **valeurs de production** du Helm chart (plus de réplicas, plus de ressources, HPA activé, etc.).

---

### `outputs.tf` — Les sorties

Identique au dev. Expose les mêmes informations (cluster name, registry URL, WIF provider, etc.).

---

## Pourquoi avoir un environnement séparé ?

La séparation dev/prd est une **bonne pratique fondamentale** :

1. **Isolation** : un bug en dev ne casse pas la prod
2. **Test avant prod** : on déploie d'abord en dev, puis en prod une fois validé
3. **Sécurité** : l'accès à la prod peut être restreint (approbation requise)
4. **Coûts différents** : en dev on prend le minimum, en prod on dimensionne correctement
5. **Protection** : `deletion_protection = true` uniquement en prod
