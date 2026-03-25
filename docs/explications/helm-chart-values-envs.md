# Explication : `helm/fastapi-app/values-dev.yaml` et `values-prd.yaml`

Ces fichiers **surchargent** les valeurs par défaut de `values.yaml` pour chaque environnement.

---

## Comment fonctionne la surcharge ?

Helm applique les valeurs en couches :
1. D'abord `values.yaml` (valeurs par défaut)
2. Puis `values-dev.yaml` ou `values-prd.yaml` (surcharge)
3. Puis les `set` de Terraform (surcharge finale)

Seules les valeurs qu'on veut **changer** sont dans le fichier de surcharge. Tout le reste garde sa valeur par défaut.

---

## `values-dev.yaml` — Environnement de développement

```yaml
replicaCount: 1
```
Un seul pod en dev.

```yaml
env:
  ENVIRONMENT: "dev"
  LOG_LEVEL: "DEBUG"         # ← DEBUG au lieu de INFO
  RATE_LIMIT: "200/minute"   # ← Plus permissif en dev
```
- **DEBUG** : logs détaillés pour faciliter le développement
- **200/minute** : rate limit plus haut pour les tests

```yaml
autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3          # ← Max 3 au lieu de 5
```
Autoscaling limité en dev pour réduire les coûts.

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
```
Ressources minimales.

```yaml
pdb:
  enabled: false
```
Pas de Pod Disruption Budget en dev (pas besoin de haute disponibilité).

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-issuer"   # ← Certificat auto-signé
  hosts:
    - host: "HERE_APP_DOMAIN_DEV"
  tls:
    - secretName: fastapi-app-tls-dev
```
En dev, on utilise un **certificat auto-signé** au lieu de Let's Encrypt (plus rapide, pas besoin de domaine réel).

---

## `values-prd.yaml` — Environnement de production

```yaml
replicaCount: 3
```
**3 pods** en production pour la haute disponibilité.

```yaml
env:
  ENVIRONMENT: "prd"
  LOG_LEVEL: "WARNING"       # ← Seulement les warnings et erreurs
  RATE_LIMIT: "100/minute"   # ← Plus strict
```
- **WARNING** : en prod, on ne veut pas les logs de debug (trop de volume)
- **100/minute** : rate limit plus strict pour protéger l'API

```yaml
autoscaling:
  minReplicas: 2        # ← Minimum 2 pods (haute dispo)
  maxReplicas: 10       # ← Jusqu'à 10 pods sous charge
```
- **2 minimum** : même sans charge, on a toujours 2 pods (si un crash, l'autre prend la relève)
- **10 maximum** : peut scaler jusqu'à 10 pods

```yaml
resources:
  requests:
    cpu: 500m          # ← 5x plus qu'en dev
    memory: 512Mi      # ← 4x plus qu'en dev
  limits:
    cpu: "1"
    memory: 1Gi
```
Plus de ressources par pod en production.

```yaml
pdb:
  enabled: true
  minAvailable: 1
```
**PDB activé** : Kubernetes doit toujours garder au moins 1 pod disponible, même pendant un rolling update.

```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"   # ← Vrai certificat HTTPS
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - host: "HERE_APP_DOMAIN_PRD"
```
En prod, on utilise un **vrai certificat Let's Encrypt** et on force le HTTPS.

---

## Comparatif dev vs prd

| Paramètre | Dev | Prd |
|-----------|-----|-----|
| `replicaCount` | 1 | 3 |
| `LOG_LEVEL` | DEBUG | WARNING |
| `RATE_LIMIT` | 200/min | 100/min |
| `autoscaling.minReplicas` | 1 | 2 |
| `autoscaling.maxReplicas` | 3 | 10 |
| `resources.requests.cpu` | 100m | 500m |
| `pdb.enabled` | false | true |
| Certificat TLS | Auto-signé | Let's Encrypt |

---

## Pourquoi ces fichiers sont nécessaires ?

Ils permettent d'utiliser le **même chart Helm** pour le dev et la prod, avec juste des configurations différentes. C'est le principe DRY (Don't Repeat Yourself) appliqué à Kubernetes.
