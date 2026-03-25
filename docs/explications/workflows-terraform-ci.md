# Explication : `.github/workflows/terraform-ci.yml`

## A quoi sert ce fichier ?

Ce fichier est un **workflow GitHub Actions** (un « pipeline CI/CD » automatisé). Son rôle est de **vérifier automatiquement ton code Terraform** chaque fois que tu ouvres une **Pull Request** (PR) vers les branches `develop` ou `main`. Il ne crée ni ne modifie rien dans le cloud — il **valide** seulement que ton code est correct avant de le fusionner.

C'est comme un correcteur orthographique pour ton infrastructure : il attrape les erreurs AVANT qu'elles n'arrivent en production.

---

## Explication ligne par ligne

```yaml
name: "Terraform CI"
```
Le nom du workflow tel qu'il apparaîtra dans l'onglet "Actions" de GitHub.

---

```yaml
on:
  pull_request:
    branches: [develop, main]
    paths:
      - "terraform/**"
```
**Quand est-ce que ce workflow se lance ?**
- `pull_request` : quand quelqu'un ouvre ou met à jour une Pull Request
- `branches: [develop, main]` : uniquement si la PR cible `develop` ou `main`
- `paths: - "terraform/**"` : uniquement si des fichiers dans le dossier `terraform/` ont été modifiés

> **Pourquoi ?** Pas besoin de valider Terraform si tu n'as changé que du code Python. Ça économise du temps et de l'argent (les runners coûtent des minutes).

---

```yaml
permissions:
  contents: read
  id-token: write
  pull-requests: write
```
**Permissions du workflow** — c'est le « niveau d'accès » que GitHub accorde au runner :
- `contents: read` : peut lire le code du repo
- `id-token: write` : peut générer un jeton OIDC (nécessaire pour s'authentifier à GCP via WIF — Workload Identity Federation)
- `pull-requests: write` : peut écrire des commentaires sur la PR (pour poster le résultat du `terraform plan`)

---

```yaml
env:
  TF_VERSION: "1.9.0"
  RUNNER_LABEL: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
```
**Variables d'environnement globales** :
- `TF_VERSION` : la version de Terraform à utiliser (fixée pour éviter les surprises)
- `RUNNER_LABEL` : si tu as défini une variable `RUNNER_LABEL` dans GitHub (pour utiliser des runners auto-hébergés ARC), elle est utilisée. Sinon, on prend `ubuntu-latest` (runner GitHub gratuit).

---

### Job 1 : `terraform-fmt`

```yaml
  terraform-fmt:
    name: "Terraform Format Check"
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
```
Premier job : vérifier le **formatage** du code Terraform.
- `runs-on` : sur quel type de machine exécuter ce job

```yaml
    steps:
      - name: Checkout
        uses: actions/checkout@v4
```
**Étape 1** : Télécharger le code du repo sur le runner. Sans ça, le runner est une machine vide.

```yaml
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}
```
**Étape 2** : Installer Terraform (version 1.9.0) sur le runner.

```yaml
      - name: Terraform Format Check
        run: terraform fmt -check -recursive terraform/
```
**Étape 3** : Vérifier que tous les fichiers `.tf` sont correctement formatés.
- `-check` : ne corrige pas, retourne juste une erreur si le formatage est incorrect
- `-recursive` : vérifie tous les sous-dossiers
- Si un fichier est mal formaté, le job échoue → la PR ne peut pas être fusionnée.

---

### Job 2 : `terraform-validate-dev`

```yaml
  terraform-validate-dev:
    name: "Validate & Plan (DEV)"
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
    needs: terraform-fmt
    environment: dev
    defaults:
      run:
        working-directory: terraform/environments/dev
```
- `needs: terraform-fmt` : ce job ne s'exécute que si le formatage est OK
- `environment: dev` : utilise les secrets et variables de l'environnement GitHub "dev"
- `working-directory` : toutes les commandes `run` s'exécutent depuis ce dossier

```yaml
      - name: Authenticate to GCP (WIF)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```
**Authentification à GCP** via Workload Identity Federation :
- Pas de clé JSON stockée ! GitHub génère un jeton OIDC que GCP vérifie, puis accorde un accès temporaire.
- `WIF_PROVIDER` et `WIF_SERVICE_ACCOUNT` sont des secrets configurés dans l'environnement GitHub "dev".

```yaml
      - name: Terraform Init
        run: terraform init
```
Télécharge les modules et les providers Terraform, et initialise le backend (GCS).

```yaml
      - name: Terraform Validate
        run: terraform validate
```
Vérifie que la syntaxe de tous les fichiers `.tf` est correcte (variables correctement référencées, types compatibles, etc.).

```yaml
      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true
```
- `terraform plan` : calcule ce que Terraform va créer/modifier/supprimer, **sans rien faire**
- `-no-color` : supprime les codes ANSI (pour un affichage propre dans GitHub)
- `-out=tfplan` : sauvegarde le plan dans un fichier
- `continue-on-error: true` : même si le plan échoue, on continue pour pouvoir poster le résultat en commentaire

```yaml
      - name: Post Plan to PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const output = `#### Terraform Plan (DEV) 🔧
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            *Triggered by @${{ github.actor }}*`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });
```
**Poste le résultat du plan en commentaire sur la PR** — comme ça, les reviewers peuvent voir exactement ce qui va changer sans exécuter Terraform eux-mêmes.

---

### Job 3 : `terraform-validate-prd`

Identique au job 2, mais pour l'environnement **production** (`environment: prd`, `working-directory: terraform/environments/prd`). On valide les deux environnements en parallèle.

---

## Pourquoi ce fichier est nécessaire ?

1. **Prévention d'erreurs** : attrape les bugs Terraform AVANT qu'ils n'atteignent l'infra réelle
2. **Revue de code** : les reviewers voient le plan Terraform directement dans la PR
3. **Gate de qualité** : la PR ne peut pas être fusionnée si le formatage ou la validation échoue
4. **Sécurité** : seul un `plan` est exécuté, jamais un `apply` — aucun risque de casser quoi que ce soit
