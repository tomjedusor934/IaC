# Explication : `.github/workflows/terraform-apply-prd.yml`

## A quoi sert ce fichier ?

Ce workflow est le **même que `terraform-apply-dev.yml`**, mais pour l'environnement **production (PRD)**. Il s'active quand du code est poussé sur la branche `main`.

---

## Différences avec la version DEV

| Aspect | DEV | PRD |
|--------|-----|-----|
| Branche déclencheuse | `develop` | `main` |
| Environnement GitHub | `dev` | `prd` |
| Dossier de travail | `terraform/environments/dev` | `terraform/environments/prd` |
| Approbation | Automatique | Peut nécessiter une **approbation manuelle** (configurable dans GitHub) |

---

## Explication ligne par ligne

```yaml
name: "Terraform Apply (PRD)"
```

```yaml
on:
  push:
    branches: [main]
    paths:
      - "terraform/**"
```
Se déclenche sur un push vers `main` (= après fusion d'une PR develop → main).

```yaml
  apply-prd:
    name: "Apply to PRD"
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
    environment: prd  # Requires manual approval via GitHub Environment protection rules
```
Le commentaire est important : dans GitHub, tu peux configurer l'environnement `prd` pour **exiger une approbation manuelle** avant que le workflow ne s'exécute. C'est un filet de sécurité supplémentaire pour la production.

> **Comment configurer l'approbation** : GitHub → Settings → Environments → prd → "Required reviewers" → ajoute ton nom.

Le reste du fichier est identique à la version DEV :
1. Checkout du code
2. Authentification WIF
3. Setup Terraform
4. Init → Plan → Apply

Les secrets (`GH_APP_ID`, `GH_APP_INSTALLATION_ID`, `GH_APP_PRIVATE_KEY`, `JWT_SECRET_KEY`) sont ceux configurés dans l'environnement GitHub `prd` — ils peuvent être différents de ceux de `dev`.

---

## Pourquoi ce fichier est nécessaire ?

1. **Séparation dev/prd** : chaque environnement a son propre workflow, ses propres secrets, et ses propres règles d'approbation
2. **Protection de la production** : le code doit passer par `develop` d'abord, puis être promu vers `main`
3. **Approbation manuelle** : en production, on peut exiger qu'un humain valide le déploiement
