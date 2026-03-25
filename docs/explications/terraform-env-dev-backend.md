# Explication : `terraform/environments/dev/backend.tf`

Ce fichier configure **Terraform lui-même** : quelle version utiliser, où stocker l'état, et quels providers (plugins) sont nécessaires.

---

## Qu'est-ce que ce fichier ?

C'est le fichier de configuration "méta" de Terraform. Il ne crée aucune ressource GCP. Il dit à Terraform :
1. Quelle version de Terraform est requise
2. Où stocker le **state** (l'état de l'infrastructure)
3. Quels **providers** (plugins) télécharger

---

## Explication ligne par ligne

### Version de Terraform

```hcl
terraform {
  required_version = ">= 1.5.0"
```
Exige au minimum Terraform 1.5.0. Si quelqu'un utilise une version plus ancienne, Terraform refusera de s'exécuter. Cela garantit la compatibilité.

### Le backend GCS

```hcl
  backend "gcs" {
    bucket = "HERE_GCS_STATE_BUCKET_NAME"
    prefix = "env/dev"
  }
```
**Concept clé : le state (état)**

Quand tu exécutes `terraform apply`, Terraform crée des ressources GCP. Il doit se souvenir de ce qu'il a créé pour pouvoir :
- Modifier les ressources existantes (au lieu d'en créer de nouvelles)
- Supprimer des ressources qui ne sont plus dans le code

Ce "souvenir" s'appelle le **state** et c'est un fichier JSON (`terraform.tfstate`).

Par défaut, ce fichier est stocké **localement**. Problème : si deux personnes font `terraform apply` en même temps, elles écrasent le state de l'autre → catastrophe.

**Solution : backend GCS** → le state est stocké dans un bucket Google Cloud Storage :
- `bucket` : le nom du bucket GCS (à remplir avec le vrai nom)
- `prefix = "env/dev"` : le "dossier" dans le bucket. L'env de dev et de prod ont des prefixes différents → des states séparés !

> `HERE_GCS_STATE_BUCKET_NAME` est un placeholder. Il faut le remplacer par le vrai nom du bucket.

### Les providers requis

```hcl
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.44"
    }
```
Le provider **google** permet de créer des ressources GCP (VPC, GKE, Cloud SQL, etc.).
- `~> 5.44` signifie >= 5.44.0 et < 6.0.0 (compatible patches et mineurs, pas de breaking changes)

```hcl
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.44"
    }
```
Le provider **google-beta** donne accès aux fonctionnalités GCP en beta (comme Dataplane V2 pour GKE).

```hcl
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
```
Le provider **kubernetes** permet de créer des ressources Kubernetes (namespaces, secrets) directement depuis Terraform.

```hcl
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
```
Le provider **helm** permet d'installer des charts Helm (nginx-ingress, cert-manager, prometheus, etc.) depuis Terraform.

```hcl
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
```
Le provider **random** génère des valeurs aléatoires (utilisé pour le mot de passe de la base de données).

### Les providers Google

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
```
Configure les providers avec le projet et la région par défaut.

### Les providers Kubernetes et Helm

```hcl
provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}
```
Ces providers se connectent **automatiquement** au cluster GKE créé par le module `gke`. Ils utilisent :
- `host` : l'adresse du cluster
- `cluster_ca_certificate` : le certificat SSL du cluster (pour HTTPS)
- `token` : le token d'authentification de l'utilisateur/SA courant

### Les data sources

```hcl
data "google_client_config" "default" {}
data "google_project" "current" {}
```
- `google_client_config` : récupère le token d'accès courant (pour les providers K8s/Helm)
- `google_project` : récupère les infos du projet GCP courant

---

## Pourquoi ce fichier est nécessaire ?

Sans ce fichier :
- Terraform ne saurait pas où stocker son état → state local = conflits
- Terraform ne saurait pas quels plugins télécharger
- Terraform ne pourrait pas se connecter au cluster GKE pour installer Helm/K8s
