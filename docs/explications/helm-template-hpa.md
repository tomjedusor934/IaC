# Explication : `helm/fastapi-app/templates/hpa.yaml`

Ce template crée un **Horizontal Pod Autoscaler (HPA)** — un mécanisme d'autoscaling automatique.

---

## Qu'est-ce qu'un HPA ?

Le HPA surveille la consommation de ressources (CPU, mémoire) des pods et **ajuste automatiquement le nombre de réplicas** :
- Si la charge augmente → il crée des pods supplémentaires
- Si la charge diminue → il supprime des pods inutiles

C'est l'outil principal d'**élasticité** dans Kubernetes.

---

## Contenu

```yaml
{{- if .Values.autoscaling.enabled }}
```
Créé uniquement si `autoscaling.enabled = true`.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
```
On utilise `autoscaling/v2` qui supporte les métriques CPU **et** mémoire (v1 ne supportait que CPU).

```yaml
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "fastapi-app.fullname" . }}
```
Le HPA cible le **Deployment** de l'application. C'est lui qui va modifier le nombre de `replicas`.

```yaml
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
```
- `minReplicas` : nombre minimum de pods (jamais en dessous, même sans charge)
- `maxReplicas` : nombre maximum de pods (plafond même sous forte charge)

```yaml
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
```
Métrique CPU : si la **moyenne d'utilisation CPU** dépasse 70% → scale up.

```yaml
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
```
Métrique mémoire : si la **moyenne d'utilisation mémoire** dépasse 80% → scale up.

---

## Exemple concret

Avec `minReplicas: 2`, `maxReplicas: 10`, `targetCPU: 70%` :

1. 2 pods tournent, chacun utilise 40% CPU → pas de changement
2. Un pic de trafic → les pods passent à 85% CPU → le HPA crée un 3ème pod
3. Le trafic continue → les 3 pods sont à 75% → un 4ème pod est créé
4. Le trafic redescend → les pods passent à 30% → les pods excédentaires sont supprimés (jusqu'à 2 minimum)

---

## Pourquoi ce fichier est nécessaire ?

Sans HPA, il faudrait ajuster manuellement le nombre de pods. L'autoscaling est **essentiel** pour :
- **Absorber les pics** de trafic automatiquement
- **Réduire les coûts** en supprimant les pods inutiles la nuit
- **Garantir la performance** en maintenant la charge par pod dans les limites
