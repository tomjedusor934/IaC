# Explication : `.github/workflows/destroy.yml`

## A quoi sert ce fichier ?

Ce workflow permet de **détruire complètement l'infrastructure** d'un environnement (dev ou prd). Il est **déclenché manuellement** et comporte des protections pour éviter les accidents.

> **Attention** : `terraform destroy` supprime TOUTES les ressources créées (VPC, GKE, Cloud SQL, etc.). C'est irréversible !

---

## Explication ligne par ligne

```yaml
name: "Terraform Destroy"
```

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to destroy"
        required: true
        type: choice
        options:
          - dev
          - prd
      confirm:
        description: "Type 'destroy' to confirm"
        required: true
        type: string
```
**`workflow_dispatch`** : ce workflow ne se lance **jamais automatiquement**. Il faut aller dans GitHub → Actions → "Terraform Destroy" → "Run workflow" et remplir les champs manuellement.

Les **inputs** sont des champs que l'utilisateur doit remplir :
- `environment` : menu déroulant (choix entre `dev` et `prd`)
- `confirm` : un champ texte libre où on doit taper exactement `destroy`

> **Pourquoi ?** C'est un mécanisme de sécurité. On ne veut pas détruire la production par erreur.

```yaml
permissions:
  contents: read
  id-token: write
```

```yaml
env:
  TF_VERSION: "1.9.0"
```

---

### Job : `destroy`

```yaml
  destroy:
    name: "Destroy ${{ inputs.environment }}"
    if: github.event.inputs.confirm == 'destroy'
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
    environment: ${{ inputs.environment }}
    defaults:
      run:
        working-directory: terraform/environments/${{ inputs.environment }}
```

Points clés :
- **`if: github.event.inputs.confirm == 'destroy'`** : le job ne s'exécute QUE si l'utilisateur a tapé exactement `destroy`. N'importe quelle autre valeur → le job est ignoré.
- **`environment: ${{ inputs.environment }}`** : utilise dynamiquement l'environnement choisi (`dev` ou `prd`)
- **`working-directory`** : pointe vers le bon dossier d'environnement

```yaml
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to GCP (WIF)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init
```
Les étapes classiques : checkout, auth, setup, init.

```yaml
      - name: Terraform Destroy
        run: terraform destroy -auto-approve
        env:
          TF_VAR_github_app_id: ${{ secrets.GH_APP_ID }}
          TF_VAR_github_app_installation_id: ${{ secrets.GH_APP_INSTALLATION_ID }}
          TF_VAR_github_app_private_key: ${{ secrets.GH_APP_PRIVATE_KEY }}
          TF_VAR_jwt_secret_key: ${{ secrets.JWT_SECRET_KEY }}
```

- **`terraform destroy -auto-approve`** : supprime TOUTES les ressources gérées par Terraform, sans demander de confirmation (la confirmation a déjà été faite via l'input `confirm`)
- Les `TF_VAR_*` sont nécessaires car Terraform a besoin de toutes ses variables, même pour un destroy (il doit lire le state et calculer les dépendances)

---

## Pourquoi ce fichier est nécessaire ?

1. **Nettoyage** : pour supprimer un environnement qui n'est plus nécessaire (évite de payer pour des ressources inutilisées)
2. **Reproductibilité** : on peut tout détruire et tout recréer proprement
3. **Triple sécurité** :
   - Le workflow est manuel (`workflow_dispatch`)
   - Il faut taper `destroy` pour confirmer
   - L'environnement `prd` peut avoir des approbations supplémentaires
4. **Environnement complet** : un seul clic détruit TOUT (VPC, GKE, Cloud SQL, etc.) au lieu de supprimer les ressources une par une dans la console GCP
