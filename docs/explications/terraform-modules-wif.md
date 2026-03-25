# Explication : `terraform/modules/wif/`

Ce module configure **Workload Identity Federation (WIF)** pour permettre à **GitHub Actions de s'authentifier sur GCP sans clé JSON**.

---

## Qu'est-ce que Workload Identity Federation ?

Traditionnellement, pour qu'un outil CI/CD accède à GCP, on crée une **clé JSON** de service account qu'on stocke comme secret GitHub. Problème : si cette clé fuite, n'importe qui peut accéder à ton projet GCP.

**WIF** résout ce problème : GitHub Actions présente un **token OIDC** (un jeton d'identité temporaire) et GCP vérifie que ce token vient bien de ton dépôt GitHub. Aucune clé secrète n'est stockée nulle part !

Le flux est :
1. GitHub Actions demande un token OIDC à GitHub
2. GitHub renvoie un token signé contenant des infos (quel repo, quel workflow, etc.)
3. GitHub Actions présente ce token à GCP
4. GCP vérifie le token auprès de GitHub (via l'URL OIDC)
5. Si les conditions sont remplies → accès autorisé

---

## Fichier : `variables.tf`

```hcl
variable "project_id" { ... }
variable "project_prefix" { ... }
variable "environment" { ... }
```
Variables standard pour identifier le projet et l'environnement.

```hcl
variable "github_owner" {
  description = "GitHub repository owner (user or org)"
}

variable "github_repo" {
  description = "GitHub repository name"
}
```
Le **propriétaire** et le **nom du dépôt** GitHub. Exemples : `github_owner = "tonpseudo"`, `github_repo = "IaC"`. Ce sont ces valeurs qui servent à restreindre l'accès.

```hcl
variable "github_actions_roles" {
  type    = list(string)
  default = [
    "roles/container.developer",
    "roles/artifactregistry.writer",
    "roles/secretmanager.secretAccessor",
    "roles/iam.serviceAccountUser",
  ]
}
```
Les **rôles IAM** accordés au service account de GitHub Actions :
| Rôle | Ce qu'il permet |
|------|-----------------|
| `container.developer` | Déployer sur GKE (kubectl) |
| `artifactregistry.writer` | Pousser des images Docker |
| `secretmanager.secretAccessor` | Lire les secrets (ex: mot de passe DB) |
| `iam.serviceAccountUser` | Utiliser d'autres service accounts (ex: pour les pods) |

---

## Fichier : `main.tf`

### Le pool d'identités

```hcl
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.project_prefix}-github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions OIDC authentication"
}
```
Un **pool** est un conteneur logique qui regroupe des identités externes. On en crée un dédié à GitHub Actions. Pense à un "groupe" dans lequel on va ajouter des fournisseurs d'identité.

### Le fournisseur OIDC

```hcl
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions OIDC"
```
On crée un **provider** (fournisseur) dans le pool. Ce provider sait parler avec GitHub via OIDC.

```hcl
  attribute_condition = "assertion.repository == '${var.github_owner}/${var.github_repo}'"
```
**Condition de sécurité critique** : seuls les tokens provenant de **ton dépôt spécifique** sont acceptés. Un autre dépôt GitHub ne pourra pas s'authentifier.

> `assertion` = le contenu du token OIDC envoyé par GitHub. Il contient le repo, la branche, l'acteur, etc.

```hcl
  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.actor"       = "assertion.actor"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
    "attribute.ref"         = "assertion.ref"
  }
```
**Mapping d'attributs** : on traduit les champs du token GitHub vers des attributs GCP :
- `subject` : identité unique (ex: `repo:user/repo:environment:dev`)
- `actor` : qui a déclenché le workflow
- `repository` : quel dépôt
- `environment` : quel environnement GitHub (dev, prd)
- `ref` : quelle branche/tag

```hcl
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
```
L'URL du serveur OIDC de GitHub. GCP l'utilise pour **vérifier la signature** des tokens.

### Le service account CI/CD

```hcl
resource "google_service_account" "github_actions" {
  account_id   = "${var.project_prefix}-gh-actions"
  display_name = "GitHub Actions CI/CD (${var.environment})"
}
```
Un **service account** GCP dédié au CI/CD. Il représente "l'identité GCP" de GitHub Actions.

### La liaison WIF → Service Account

```hcl
resource "google_service_account_iam_member" "wif_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${...pool...}/subject/repo:${var.github_owner}/${var.github_repo}:environment:${var.environment}"
}
```
C'est le **cœur de WIF** : on autorise les tokens GitHub qui correspondent au pattern `repo:owner/repo:environment:env` à **emprunter l'identité** du service account.

Donc quand GitHub Actions s'authentifie :
1. Il présente son token OIDC
2. GCP vérifie que le token vient du bon repo ET du bon environnement
3. GCP lui donne un token temporaire du service account

### Les rôles IAM du service account

```hcl
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset(var.github_actions_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
```
`for_each` itère sur la liste des rôles et crée un binding IAM pour chacun. Le service account reçoit les 4 rôles nécessaires au CI/CD.

---

## Fichier : `outputs.tf`

```hcl
output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}
```
Le **nom complet du provider WIF** — c'est cette valeur qu'on met dans le workflow GitHub Actions pour l'étape `google-github-actions/auth`.

```hcl
output "service_account_email" {
  value = google_service_account.github_actions.email
}
```
L'email du service account — aussi nécessaire dans les workflows.

---

## Pourquoi ce module est nécessaire ?

Sans WIF, il faudrait :
1. Créer une clé JSON manuellement
2. La stocker comme secret GitHub
3. La renouveler régulièrement
4. Risquer une fuite de credentials

Avec WIF :
- **Zéro secret** stocké dans GitHub
- **Tokens temporaires** (durée de vie courte)
- **Scope limité** : seul TON repo + TON environnement peut s'authentifier
- **Meilleure pratique** recommandée par Google
