# Explication : `terraform/environments/dev/variables.tf`

Ce fichier déclare toutes les **variables d'entrée** de l'environnement de développement.

---

## Qu'est-ce qu'une variable Terraform ?

Une variable est un paramètre configurable. Au lieu de coder en dur `project_id = "mon-projet"` partout, on déclare une variable et on lui donne une valeur dans un fichier séparé (`terraform.tfvars`).

Avantages :
- **Réutilisable** : le même code peut servir pour dev et prod avec des valeurs différentes
- **Sécurisé** : les variables `sensitive = true` ne s'affichent jamais dans les logs

---

## Explication des variables

### Variables de base

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}
```
L'identifiant unique de ton projet GCP (ex: `my-project-123456`). Pas de valeur par défaut → **obligatoire**.

```hcl
variable "region" {
  default = "europe-west1"
}
```
La région GCP. `europe-west1` = Belgique (le datacenter le plus proche de la France).

```hcl
variable "environment" {
  default = "dev"
}
```
Le nom de l'environnement. Utilisé dans les noms de ressources et les labels.

### Variables GitHub

```hcl
variable "github_owner" { ... }
variable "github_repo" { ... }
```
Ton pseudo GitHub et le nom du repo. Utilisés par le module WIF pour restreindre l'accès OIDC.

### Variable de l'image Docker

```hcl
variable "app_image_tag" {
  default = "latest"
}
```
Le tag de l'image Docker à déployer. En dev, on utilise `latest`. En prod, on utilise un tag précis (ex: `sha-abc1234`). Peut être surchargé par le pipeline CI/CD.

### Variables sensibles (GitHub App pour les runners)

```hcl
variable "github_app_id" {
  sensitive = true
}

variable "github_app_installation_id" {
  sensitive = true
}

variable "github_app_private_key" {
  sensitive = true
}
```
Les credentials d'une **GitHub App** utilisée par ARC (Actions Runner Controller) pour enregistrer les runners self-hosted. `sensitive = true` empêche Terraform d'afficher ces valeurs dans les logs.

> Ces valeurs sont passées via des variables d'environnement dans le CI/CD : `TF_VAR_github_app_id`, etc.

### Variable JWT

```hcl
variable "jwt_secret_key" {
  sensitive = true
}
```
La clé secrète utilisée par FastAPI pour **signer les tokens JWT** (authentification des utilisateurs). Aussi passée via variable d'environnement.

---

## Pourquoi ce fichier est nécessaire ?

Il **déclare** tous les paramètres configurables. Sans lui, Terraform ne saurait pas quelles entrées attendre. C'est le "contrat" entre le code Terraform et celui qui l'exécute.
