# Explication : `helm/fastapi-app/templates/pdb.yaml`

Ce template crée un **Pod Disruption Budget (PDB)** — un garde-fou pour la haute disponibilité.

---

## Qu'est-ce qu'un PDB ?

Un PDB dit à Kubernetes : "tu peux supprimer des pods, mais **assure-toi qu'il en reste toujours X de disponibles**".

Sans PDB, Kubernetes peut supprimer **tous** les pods en même temps lors de :
- Un rolling update
- Un **drain** de nœud (maintenance, mise à jour du nœud)
- Un scale down du cluster autoscaler

Avec un PDB, Kubernetes attend qu'un nouveau pod soit prêt avant de supprimer l'ancien.

---

## Contenu

```yaml
{{- if .Values.pdb.enabled }}
```
Activé uniquement en production (`pdb.enabled = true` dans values-prd.yaml).

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "fastapi-app.fullname" . }}
```
Ressource de type PodDisruptionBudget.

```yaml
spec:
  minAvailable: {{ .Values.pdb.minAvailable }}
```
`minAvailable: 1` signifie : "il doit **toujours** y avoir au moins 1 pod en état Running et Ready".

Alternative : on pourrait utiliser `maxUnavailable: 1` ("au maximum 1 pod peut être indisponible à la fois").

```yaml
  selector:
    matchLabels:
      {{- include "fastapi-app.selectorLabels" . | nindent 6 }}
```
Cible les pods de l'application (même sélecteur que le Deployment et le Service).

---

## Exemple concret

Avec 3 réplicas en production et `minAvailable: 1` :

1. Kubernetes veut faire un drain d'un nœud
2. Le PDB dit : "OK, mais garde au moins 1 pod disponible"
3. Kubernetes supprime un pod, attend que le nouveau pod soit Ready
4. Puis supprime le suivant, re-attend, etc.
5. À chaque instant, au moins 1 pod répond aux requêtes

---

## Pourquoi ce fichier est nécessaire ?

En production, **zéro downtime** est l'objectif. Le PDB garantit qu'il y a toujours au moins un pod capable de servir les utilisateurs, même pendant les opérations de maintenance.

C'est désactivé en dev car on accepte les interruptions momentanées.
