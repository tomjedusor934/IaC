# Explication : `.github/workflows/app-deploy-prd.yml`

## A quoi sert ce fichier ?

Ce workflow déploie l'application en **production (PRD)**. Il se déclenche quand un **tag Git** commençant par `v` est poussé (ex: `v1.0.0`, `v1.2.3`).

---

## Différences clés avec la version DEV

| Aspect | DEV (`app-deploy-dev.yml`) | PRD (`app-deploy-prd.yml`) |
|--------|---------------------------|---------------------------|
| Déclencheur | Push sur `develop` | Push d'un tag `v*` |
| Tag de l'image | SHA du commit (`a1b2c3d4`) | Version sémantique (`v1.0.0`) |
| Fichier de valeurs Helm | `values-dev.yaml` | `values-prd.yaml` |
| Approbation | Automatique | Peut nécessiter approbation manuelle |

---

## Explication des parties spécifiques

```yaml
on:
  push:
    tags:
      - "v*"
```
Se déclenche quand un tag Git commençant par `v` est poussé. Exemples : `v1.0.0`, `v2.1.0-beta`.

> **Pourquoi des tags ?** En production, on ne déploie pas à chaque commit. On crée explicitement un tag quand on décide qu'une version est prête. C'est un acte délibéré.

```yaml
      - name: Get version from tag
        id: tag
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
```
Extrait le nom du tag (ex: `v1.0.0`) depuis la référence Git complète (`refs/tags/v1.0.0`).
- `${GITHUB_REF#refs/tags/}` : c'est une syntaxe bash qui « coupe » le préfixe `refs/tags/`

```yaml
    environment: prd  # Requires manual approval
```
L'environnement `prd` peut être configuré pour exiger une **approbation manuelle**. Le workflow attend qu'un revieweur approuve avant de continuer.

Le reste suit la même structure que le workflow DEV, avec `values-prd.yaml` et le tag version au lieu du SHA.

---

## Pourquoi ce fichier est nécessaire ?

1. **Déploiement contrôlé** : seuls les tags explicites déclenchent un déploiement en production
2. **Versioning sémantique** : les images de production sont tagguées avec des versions lisibles (`v1.0.0`)
3. **Approbation** : filet de sécurité humain avant le déploiement en production
4. **Séparation des flux** : le flux de production est complètement indépendant du flux de développement
