# Explication : `terraform/environments/dev/outputs.tf`

Ce fichier **expose les informations utiles** après l'exécution de `terraform apply`.

---

## Qu'est-ce qu'un output Terraform ?

Quand tu fais `terraform apply`, Terraform crée des dizaines de ressources. Certaines infos sont nécessaires après coup (pour configurer GitHub Actions, se connecter au cluster, etc.). Les outputs les affichent à la fin du `apply` et les rendent accessibles programmatiquement.

---

## Les outputs

```hcl
output "gke_cluster_name" {
  value = module.gke.cluster_name
}
```
Le nom du cluster GKE. Utilisé pour configurer `kubectl` :
```bash
gcloud container clusters get-credentials <CLUSTER_NAME> --region europe-west1
```

```hcl
output "gke_cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}
```
L'adresse IP du serveur API Kubernetes. Marqué `sensitive` car c'est une info de sécurité (l'IP du contrôle plane).

```hcl
output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}
```
L'URL pour pousser/tirer des images Docker (ex: `europe-west1-docker.pkg.dev/projet/taskmanager-dev-docker`).

```hcl
output "cloudsql_instance_connection_name" {
  value = module.cloudsql.instance_connection_name
}

output "cloudsql_private_ip" {
  value = module.cloudsql.private_ip
}
```
Les infos de connexion Cloud SQL. Le `connection_name` est utilisé par le Cloud SQL Auth Proxy.

```hcl
output "wif_provider" {
  value = module.wif.workload_identity_provider
}

output "wif_service_account_email" {
  value = module.wif.service_account_email
}
```
Les infos WIF à mettre dans les **secrets/variables GitHub** pour configurer les workflows.

```hcl
output "app_service_account_email" {
  value = module.iam.app_service_account_email
}
```
Le service account GCP de l'application (pour vérification).

---

## Comment utiliser les outputs

Après `terraform apply`, tu peux récupérer une valeur :
```bash
terraform output artifact_registry_url
# → europe-west1-docker.pkg.dev/mon-projet/taskmanager-dev-docker
```

Ou toutes les valeurs sous forme JSON :
```bash
terraform output -json
```

---

## Pourquoi ce fichier est nécessaire ?

Sans outputs, il faudrait aller **chercher manuellement** les infos dans la console GCP après chaque déploiement. Les outputs servent de "récapitulatif" et permettent l'**automatisation** (le CI/CD peut lire les outputs pour les étapes suivantes).
