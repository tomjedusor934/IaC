# Explication : `.github/workflows/terraform-apply-dev.yml`

## A quoi sert ce fichier ?

Ce workflow **applique automatiquement les changements Terraform** dans l'environnement **DEV** chaque fois que du code est poussé sur la branche `develop`. C'est le déploiement automatique de l'infrastructure de développement.

Contrairement à `terraform-ci.yml` qui ne fait que vérifier, celui-ci **crée/modifie/supprime réellement des ressources** dans GCP.

---

## Explication ligne par ligne

```yaml
name: "Terraform Apply (DEV)"
```
Nom affiché dans GitHub Actions.

```yaml
on:
  push:
    branches: [develop]
    paths:
      - "terraform/**"
```
Se déclenche quand :
- Un `push` est fait sur la branche `develop` (typiquement après la fusion d'une PR)
- Et que des fichiers dans `terraform/` ont été modifiés

> **Pourquoi `push` et pas `pull_request` ?** Parce qu'on veut appliquer les changements uniquement APRÈS la fusion de la PR, pas pendant la revue.

```yaml
permissions:
  contents: read
  id-token: write
```
- `contents: read` : lire le repo
- `id-token: write` : générer un jeton OIDC pour WIF (pas besoin de `pull-requests: write` car on ne commente pas de PR)

```yaml
env:
  TF_VERSION: "1.9.0"
```
Version de Terraform fixée.

---

### Job : `apply-dev`

```yaml
  apply-dev:
    name: "Apply to DEV"
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
    environment: dev
    defaults:
      run:
        working-directory: terraform/environments/dev
```
- `environment: dev` : utilise les secrets/variables de l'environnement GitHub "dev"
- `working-directory` : on travaille dans le dossier de l'environnement dev

```yaml
      - name: Checkout
        uses: actions/checkout@v4
```
Télécharge le code du repo.

```yaml
      - name: Authenticate to GCP (WIF)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```
Authentification sans clé JSON via Workload Identity Federation.

```yaml
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
```
Installation de Terraform.

```yaml
      - name: Terraform Init
        run: terraform init
```
Initialise Terraform (télécharge providers, configure le backend GCS).

```yaml
      - name: Terraform Plan
        run: terraform plan -out=tfplan
```
Calcule les changements à appliquer et les sauvegarde dans `tfplan`.

```yaml
      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        env:
          TF_VAR_github_app_id: ${{ secrets.GH_APP_ID }}
          TF_VAR_github_app_installation_id: ${{ secrets.GH_APP_INSTALLATION_ID }}
          TF_VAR_github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
          TF_VAR_jwt_secret_key: ${{ secrets.JWT_SECRET_KEY }}
```
**Applique le plan** — c'est ici que les ressources GCP sont réellement créées/modifiées.

- `-auto-approve` : pas de confirmation interactive (on est en CI, pas de terminal interactif)
- `tfplan` : applique exactement le plan calculé à l'étape précédente (pas de surprise)
- Les variables `TF_VAR_*` passent des secrets GitHub comme variables Terraform :
  - `GH_APP_ID` / `GH_APP_INSTALLATION_ID` / `GH_APP_PRIVATE_KEY` : identifiants de la GitHub App pour ARC
  - `JWT_SECRET_KEY` : clé secrète pour signer les tokens JWT de l'application

> **Convention Terraform** : `TF_VAR_nomdevariable` est automatiquement lu comme la variable `nomdevariable` dans Terraform.

---

## Pourquoi ce fichier est nécessaire ?

1. **Déploiement automatique** : dès qu'une PR est fusionnée dans `develop`, l'infra dev se met à jour
2. **Reproductibilité** : le même code produit toujours la même infra
3. **Pas de `terraform apply` manuel** : réduit le risque d'erreurs humaines
4. **Secrets sécurisés** : les credentials sensibles sont dans GitHub Secrets, jamais dans le code
