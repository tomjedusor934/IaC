# Explication : `terraform/modules/cloudsql/`

Ce module crée une **base de données PostgreSQL managée** sur Google Cloud SQL.

---

## Qu'est-ce que Cloud SQL ?

Cloud SQL est le service de bases de données relationnelles managées de GCP. Au lieu de gérer toi-même un serveur PostgreSQL (mises à jour, sauvegardes, réplication, sécurité), Google s'en occupe. Toi, tu as juste une adresse IP et des credentials pour t'y connecter.

---

## Fichier : `variables.tf`

```hcl
variable "network_self_link" { ... }
variable "private_service_access_connection" { ... }
```
Références au VPC. Cloud SQL a besoin du réseau pour se connecter en IP privée. Le `private_service_access_connection` est une **dépendance** — la connexion PSA doit exister AVANT de créer Cloud SQL.

```hcl
variable "db_tier" {
  default = "db-custom-2-8192"
}
```
Le **tier** définit la taille de la machine :
- `db-custom-2-8192` = 2 vCPU, 8 Go de RAM (prd)
- `db-custom-1-3840` = 1 vCPU, 3.75 Go de RAM (dev)

```hcl
variable "availability_type" {
  default = "ZONAL"
}
```
- `ZONAL` : instance dans une seule zone (dev — moins cher)
- `REGIONAL` : instance avec un réplica standby dans une autre zone (prd — haute disponibilité)

---

## Fichier : `main.tf`

### Génération du mot de passe

```hcl
resource "random_password" "db_password" {
  length  = 24
  special = true
}
```
Génère automatiquement un mot de passe aléatoire de 24 caractères. **On ne code jamais un mot de passe en dur !**

### L'instance Cloud SQL

```hcl
resource "google_sql_database_instance" "main" {
  name                = "${var.project_prefix}-postgres"
  database_version    = "POSTGRES_15"
  deletion_protection = var.deletion_protection

  depends_on = [var.private_service_access_connection]
```
- `POSTGRES_15` : version 15 de PostgreSQL
- `depends_on` : attend que le PSA soit créé avant de créer l'instance (sinon erreur)

```hcl
  settings {
    tier              = var.db_tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true
```
- `PD_SSD` : disque SSD (plus rapide que `PD_HDD`)
- `disk_autoresize = true` : le disque grandit automatiquement si nécessaire

```hcl
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_self_link
      enable_private_path_for_google_cloud_services = true
    }
```
**Configuration réseau cruciale** :
- `ipv4_enabled = false` : **pas d'IP publique** ! La base n'est accessible que depuis le VPC
- `private_network` : connecte l'instance au VPC via PSA
- `enable_private_path_for_google_cloud_services` : permet aux services Google (Dataflow, etc.) d'accéder via le réseau privé

```hcl
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = var.environment == "prd"
      start_time                     = "03:00"
      transaction_log_retention_days = var.environment == "prd" ? 7 : 3

      backup_retention_settings {
        retained_backups = var.environment == "prd" ? 30 : 7
      }
    }
```
**Sauvegardes** :
- Activées pour tous les environnements
- `point_in_time_recovery` : en production, on peut restaurer à n'importe quelle seconde (pas juste à la dernière sauvegarde)
- `start_time = "03:00"` : les sauvegardes se font à 3h du matin
- On garde 30 jours de sauvegardes en prd, 7 en dev

> L'opérateur ternaire `condition ? valeur_si_vrai : valeur_si_faux` est une syntaxe Terraform pour les conditions inline.

```hcl
    maintenance_window {
      day          = 7  # Dimanche
      hour         = 3
      update_track = "stable"
    }
```
Fenêtre de maintenance : dimanche à 3h du matin, canal stable.

```hcl
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
```
**Flags de base de données** qui activent le logging de sécurité :
- `log_checkpoints` : journalise les points de contrôle (performance)
- `log_connections` / `log_disconnections` : journalise qui se connecte/déconnecte (audit)

### La base de données et l'utilisateur

```hcl
resource "google_sql_database" "app" {
  name     = "taskmanager"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "app" {
  name     = "taskmanager"
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
}
```
Crée la base de données `taskmanager` et l'utilisateur `taskmanager` avec le mot de passe généré aléatoirement.

### Stockage du mot de passe dans Secret Manager

```hcl
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_prefix}-db-password"
  replication { auto {} }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
```
Le mot de passe est stocké dans **Secret Manager** (coffre-fort de GCP). On ne le stocke jamais dans du code ou dans des fichiers de configuration. Les applications et les humains autorisés peuvent le récupérer via l'API.

---

## Fichier : `outputs.tf`

```hcl
output "instance_connection_name" {
  value = google_sql_database_instance.main.connection_name
}
```
Format : `projet:region:instance`. Utilisé par le **Cloud SQL Auth Proxy** pour se connecter à la base de données.

```hcl
output "private_ip" { ... }
output "database_name" { ... }
output "database_user" { ... }
output "database_password_secret_id" { ... }
```
Toutes les infos nécessaires pour que l'application se connecte.

---

## Pourquoi ce module est nécessaire ?

L'application FastAPI a besoin d'une base de données pour stocker les tâches. Ce module :
1. Crée une base PostgreSQL **sécurisée** (IP privée uniquement)
2. Génère un mot de passe **fort et aléatoire**
3. Le stocke dans **Secret Manager** (pas dans le code)
4. Configure les **sauvegardes automatiques**
5. Active le **logging d'audit**
