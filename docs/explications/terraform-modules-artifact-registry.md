# Explication : `terraform/modules/artifact-registry/`

Ce module crée un **registre Docker privé** sur GCP pour stocker les images de conteneur de l'application.

---

## Qu'est-ce qu'Artifact Registry ?

Quand tu fais `docker build`, tu obtiens une **image Docker** locale. Pour que Kubernetes (GKE) puisse utiliser cette image, il faut la stocker quelque part où le cluster peut la télécharger.

**Artifact Registry** est le service GCP qui sert de "Docker Hub privé". Avantages :
- **Privé** : seuls les comptes autorisés peuvent lire/écrire
- **Proche de GKE** : même réseau Google → téléchargement rapide
- **Intégré** : scan de vulnérabilités, politiques de nettoyage

---

## Fichier : `variables.tf`

```hcl
variable "project_id" { ... }
variable "project_prefix" { ... }
variable "region" { ... }
```
Variables standard. La **région** est importante : il vaut mieux que le registre soit dans la même région que le cluster GKE (ici `europe-west1`).

```hcl
variable "labels" {
  type    = map(string)
  default = {}
}
```
Labels optionnels pour taguer la ressource (ex: `environment = "dev"`).

---

## Fichier : `main.tf`

```hcl
resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.project_prefix}-docker"
  description   = "Docker container registry for ${var.project_prefix}"
  format        = "DOCKER"
```
Crée un dépôt au format **DOCKER**. Artifact Registry supporte aussi d'autres formats (Maven, npm, Python), mais ici on ne stocke que des images Docker.

```hcl
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }
```
**Politique de nettoyage** : on ne garde que les **10 versions les plus récentes** de chaque image. Les anciennes sont automatiquement supprimées.

Pourquoi ? Les images Docker font plusieurs centaines de Mo. Sans nettoyage, le stockage (et les coûts) augmentent indéfiniment.

```hcl
  labels = var.labels
}
```
Les labels sont des métadonnées clé-valeur pour organiser et filtrer les ressources GCP.

---

## Fichier : `outputs.tf`

```hcl
output "repository_id" {
  value = google_artifact_registry_repository.docker.repository_id
}
```
L'ID du dépôt (ex: `rattrapage-docker`).

```hcl
output "repository_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${...repository_id...}"
}
```
L'**URL complète** du dépôt. C'est cette URL qu'on utilise pour pousser et tirer des images :

```bash
# Pousser une image
docker push europe-west1-docker.pkg.dev/MON-PROJET/rattrapage-docker/fastapi-app:v1.0

# Tirer une image (fait par GKE automatiquement)
docker pull europe-west1-docker.pkg.dev/MON-PROJET/rattrapage-docker/fastapi-app:v1.0
```

Le format est : `<REGION>-docker.pkg.dev/<PROJECT_ID>/<REPO_ID>`

---

## Pourquoi ce module est nécessaire ?

Sans Artifact Registry :
- Les images Docker n'auraient **nulle part où être stockées**
- GKE ne pourrait pas **télécharger** les images pour créer les pods
- On devrait utiliser un registre public (Docker Hub) → pas sécurisé pour du code propriétaire

Artifact Registry est la **pierre angulaire** du pipeline CI/CD :
1. GitHub Actions **build** l'image Docker
2. GitHub Actions **push** l'image vers Artifact Registry
3. Helm/GKE **pull** l'image depuis Artifact Registry pour créer les pods
