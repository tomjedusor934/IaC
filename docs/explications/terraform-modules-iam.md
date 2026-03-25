# Explication : `terraform/modules/iam/`

Ce module crée le **service account de l'application** et configure **GKE Workload Identity** pour que les pods FastAPI puissent accéder aux services GCP de manière sécurisée.

---

## Qu'est-ce que GKE Workload Identity ?

C'est le même concept que WIF (le module précédent), mais pour les **pods Kubernetes** au lieu de GitHub Actions.

Problème classique : ton application dans un pod a besoin d'accéder à Cloud SQL ou Secret Manager. Comment l'authentifier ?
- ❌ Monter une clé JSON dans le pod → risque de fuite
- ✅ **Workload Identity** : le pod utilise son ServiceAccount Kubernetes, qui est "lié" à un ServiceAccount GCP

Le flux :
1. Le pod a un ServiceAccount Kubernetes (`fastapi-app`)
2. Ce SA Kubernetes est autorisé à "emprunter l'identité" d'un SA GCP
3. Quand le pod appelle une API GCP, GKE fait automatiquement la traduction
4. Le pod obtient un token GCP temporaire → accès autorisé

---

## Fichier : `variables.tf`

```hcl
variable "project_id" { ... }
variable "project_prefix" { ... }
variable "environment" { ... }
```
Variables standard.

```hcl
variable "k8s_namespace" {
  default = "app"
}
```
Le **namespace Kubernetes** où tourne l'application. Les namespaces sont comme des "dossiers" dans Kubernetes pour organiser les ressources.

```hcl
variable "k8s_service_account" {
  default = "fastapi-app"
}
```
Le nom du **ServiceAccount Kubernetes** utilisé par les pods de l'application. Ce nom doit correspondre à ce qui est configuré dans le Helm chart.

---

## Fichier : `main.tf`

### Le service account GCP de l'application

```hcl
resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "${var.project_prefix}-app-sa"
  display_name = "FastAPI App SA (${var.environment})"
  description  = "Service account for FastAPI application pods in ${var.environment}"
}
```
Crée un **service account GCP** dédié à l'application. Il représente "l'identité GCP" de tes pods FastAPI.

### Rôle Cloud SQL

```hcl
resource "google_project_iam_member" "app_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app.email}"
}
```
Autorise le service account à **se connecter à Cloud SQL**. Sans ce rôle, les pods ne pourraient pas accéder à la base de données.

### Rôle Secret Manager

```hcl
resource "google_project_iam_member" "app_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app.email}"
}
```
Autorise le service account à **lire les secrets** (comme le mot de passe de la base de données). L'application en a besoin pour récupérer ses credentials.

### La liaison Workload Identity

```hcl
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}
```
**La ligne la plus importante du module.** Elle dit :

> « Le ServiceAccount Kubernetes `fastapi-app` dans le namespace `app` est autorisé à agir comme le ServiceAccount GCP `app-sa` »

Le format du member est :
```
serviceAccount:<PROJECT_ID>.svc.id.goog[<NAMESPACE>/<K8S_SA>]
```

C'est une convention GKE. `<PROJECT_ID>.svc.id.goog` est le domaine d'identité du cluster GKE.

---

## Fichier : `outputs.tf`

```hcl
output "app_service_account_email" {
  value = google_service_account.app.email
}
```
L'email du SA GCP (ex: `rattrapage-app-sa@project.iam.gserviceaccount.com`). Used dans le Helm chart pour annoter le ServiceAccount Kubernetes.

```hcl
output "app_service_account_name" {
  value = google_service_account.app.name
}
```
Le nom complet de la ressource.

---

## Pourquoi ce module est nécessaire ?

Sans ce module, les pods FastAPI :
- Ne pourraient pas accéder à **Cloud SQL** (pas de credentials)
- Ne pourraient pas lire les **secrets** (mot de passe DB)
- Devraient utiliser des **clés JSON** montées dans les pods (anti-pattern de sécurité)

Avec Workload Identity :
- **Pas de secrets** dans les pods
- **Tokens temporaires** générés automatiquement par GKE
- **Principe du moindre privilège** : chaque SA a uniquement les rôles nécessaires
