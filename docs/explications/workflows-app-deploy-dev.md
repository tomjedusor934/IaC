# Explication : `.github/workflows/app-deploy-dev.yml`

## A quoi sert ce fichier ?

Ce workflow **construit l'image Docker de l'application, la pousse vers Artifact Registry, et la déploie sur GKE** dans l'environnement DEV. Il s'active quand du code est poussé sur la branche `develop`.

C'est le déploiement continu (CD) de l'application.

---

## Explication ligne par ligne

```yaml
name: "App Deploy (DEV)"
```

```yaml
on:
  push:
    branches: [develop]
    paths:
      - "app/**"
      - "helm/fastapi-app/**"
```
Se déclenche après un push sur `develop` qui modifie le code de l'app ou le chart Helm.

```yaml
permissions:
  contents: read
  id-token: write
```
- `id-token: write` : nécessaire pour WIF (on va interagir avec GCP)

```yaml
env:
  REGION: "europe-west1"
```
Région GCP — utilisée pour construire l'URL d'Artifact Registry.

---

### Job : `deploy-dev`

```yaml
      - name: Authenticate to GCP (WIF)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```
Authentification WIF (comme pour Terraform).

```yaml
      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v2
```
Installe et configure le CLI `gcloud` avec les credentials WIF.

```yaml
      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev --quiet
```
Configure Docker pour pouvoir pousser des images vers Artifact Registry de GCP. La commande dit à Docker : "quand tu pousses vers `europe-west1-docker.pkg.dev`, utilise les credentials gcloud".

```yaml
      - name: Set image tag
        id: tag
        run: echo "TAG=$(echo $GITHUB_SHA | cut -c1-8)" >> $GITHUB_OUTPUT
```
Crée un **tag basé sur le SHA du commit** (les 8 premiers caractères). Par exemple : `a1b2c3d4`.

> **Pourquoi le SHA ?** Chaque image est unique et traçable. On sait exactement quel commit a produit quelle image. On n'utilise pas `latest` en production car c'est ambigu.

```yaml
      - name: Build and Push Docker image
        uses: docker/build-push-action@v6
        with:
          context: ./app
          push: true
          tags: |
            ${{ env.REGION }}-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/${{ secrets.AR_REPO_NAME }}/fastapi-app:${{ steps.tag.outputs.TAG }}
            ${{ env.REGION }}-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/${{ secrets.AR_REPO_NAME }}/fastapi-app:latest
```
Construit l'image Docker et la pousse vers Artifact Registry avec **deux tags** :
- Le SHA du commit (pour la traçabilité)
- `latest` (pour la commodité)

L'URL complète ressemble à : `europe-west1-docker.pkg.dev/mon-projet/mon-repo/fastapi-app:a1b2c3d4`

```yaml
      - name: Get GKE credentials
        uses: google-github-actions/get-gke-credentials@v2
        with:
          cluster_name: ${{ secrets.GKE_CLUSTER_NAME }}
          location: ${{ env.REGION }}
```
Récupère le `kubeconfig` pour pouvoir communiquer avec le cluster GKE. C'est comme obtenir un badge d'accès à un bâtiment.

```yaml
      - name: Setup Helm
        uses: azure/setup-helm@v4
```
Installe Helm sur le runner.

```yaml
      - name: Helm upgrade (DEV)
        run: |
          helm upgrade --install fastapi-app ./helm/fastapi-app \
            --namespace app \
            --values ./helm/fastapi-app/values-dev.yaml \
            --set image.tag=${{ steps.tag.outputs.TAG }} \
            --set image.repository=${{ env.REGION }}-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/${{ secrets.AR_REPO_NAME }}/fastapi-app \
            --set env.JWT_SECRET_KEY=${{ secrets.JWT_SECRET_KEY }} \
            --set env.DATABASE_PASSWORD=${{ secrets.DB_PASSWORD }} \
            --set cloudSqlProxy.instanceConnectionName=${{ secrets.CLOUDSQL_CONNECTION_NAME }} \
            --wait --timeout 5m
```
**C'est la commande de déploiement**. Décomposons :

- `helm upgrade --install` : met à jour le déploiement s'il existe, le crée sinon
- `fastapi-app` : nom du release Helm
- `./helm/fastapi-app` : chemin vers le chart Helm local
- `--namespace app` : déploie dans le namespace Kubernetes "app"
- `--values ./helm/fastapi-app/values-dev.yaml` : utilise les valeurs spécifiques au DEV
- `--set image.tag=...` : surcharge le tag de l'image avec le SHA du commit
- `--set image.repository=...` : surcharge l'URL de l'image
- `--set env.JWT_SECRET_KEY=...` : passe le secret JWT depuis GitHub Secrets
- `--set env.DATABASE_PASSWORD=...` : passe le mot de passe de la BDD
- `--set cloudSqlProxy.instanceConnectionName=...` : passe l'adresse de connexion Cloud SQL
- `--wait` : attend que le déploiement soit complètement terminé
- `--timeout 5m` : échoue si ça prend plus de 5 minutes

---

## Pourquoi ce fichier est nécessaire ?

1. **CD automatique** : chaque merge dans `develop` déploie automatiquement en DEV
2. **Images traçables** : chaque image est tagguée avec le SHA du commit
3. **Secrets injectés au déploiement** : pas de mots de passe dans le code
4. **Helm** : gère les mises à jour proprement (rolling update des pods)
