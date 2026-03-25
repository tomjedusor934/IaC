# Explication : `terraform/environments/dev/terraform.tfvars`

Ce fichier donne les **valeurs concrètes** aux variables déclarées dans `variables.tf`.

---

## Qu'est-ce qu'un fichier `.tfvars` ?

Quand tu fais `terraform apply`, Terraform cherche un fichier `terraform.tfvars` dans le répertoire courant et charge automatiquement les valeurs qu'il contient. C'est comme un fichier de configuration.

---

## Contenu

```hcl
project_id  = "HERE_GCP_PROJECT_ID_DEV"
region      = "europe-west1"
environment = "dev"
```
- `project_id` : **placeholder** à remplacer par ton vrai ID de projet GCP
- `region` : la région Europe de l'Ouest 1 (Belgique)
- `environment` : on est en dev

```hcl
github_owner = "HERE_GITHUB_OWNER"
github_repo  = "HERE_GITHUB_REPO_NAME"
```
- `github_owner` : **placeholder** → ton pseudo GitHub
- `github_repo` : **placeholder** → le nom de ton dépôt

```hcl
app_image_tag = "latest"
```
En dev, on déploie l'image la plus récente.

---

## Et les variables sensibles ?

Tu remarques que `github_app_id`, `github_app_installation_id`, `github_app_private_key` et `jwt_secret_key` ne sont **PAS** dans ce fichier. C'est volontaire !

Les valeurs sensibles sont passées via des **variables d'environnement** :
```bash
export TF_VAR_github_app_id="12345"
export TF_VAR_github_app_installation_id="67890"
export TF_VAR_github_app_private_key="-----BEGIN RSA PRIVATE KEY-----..."
export TF_VAR_jwt_secret_key="super-secret-key"
```

Terraform détecte automatiquement les variables d'environnement préfixées par `TF_VAR_`.

> **Règle d'or** : ne JAMAIS mettre de secrets dans un fichier commité sur Git !

---

## Pourquoi ce fichier est nécessaire ?

Il fournit les valeurs non-sensibles de l'environnement dev. Sans lui, il faudrait passer toutes les valeurs manuellement à chaque `terraform apply`. C'est le fichier de configuration principal de l'environnement.
