# Explication : `helm/fastapi-app/templates/service.yaml`

Ce template crée un **Service Kubernetes** pour l'application.

---

## Qu'est-ce qu'un Service ?

Les pods Kubernetes sont **éphémères** : ils peuvent être créés, détruits et recréés avec des adresses IP différentes. Un Service fournit une **adresse stable** pour accéder aux pods.

Sans Service, il faudrait connaître l'IP de chaque pod (qui change tout le temps). Avec un Service, on a une seule adresse qui route automatiquement vers les pods disponibles.

---

## Contenu

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "fastapi-app.fullname" . }}
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
```
Métadonnées standard avec le nom et les labels du chart.

```yaml
spec:
  type: {{ .Values.service.type }}
```
`ClusterIP` (valeur par défaut) : le Service n'est accessible qu'**à l'intérieur du cluster**. Le trafic externe passe par l'Ingress.

Autres types possibles :
- `LoadBalancer` : crée un load balancer GCP (exposition directe)
- `NodePort` : ouvre un port sur chaque nœud

```yaml
  ports:
    - port: {{ .Values.service.port }}          # 80
      targetPort: {{ .Values.service.targetPort }} # 8000
      protocol: TCP
      name: http
```
- `port: 80` : le port du Service (ce que les autres pods utilisent)
- `targetPort: 8000` : le port du container FastAPI

Quand quelqu'un envoie une requête au Service sur le port 80, Kubernetes la redirige vers un pod sur le port 8000.

```yaml
  selector:
    {{- include "fastapi-app.selectorLabels" . | nindent 4 }}
```
Le **sélecteur** identifie les pods ciblés par ce Service. Seuls les pods avec les labels correspondants reçoivent du trafic.

---

## Flux du trafic

```
Internet → Load Balancer → Ingress → Service (:80) → Pod (:8000)
```

---

## Pourquoi ce fichier est nécessaire ?

Sans Service, ni l'Ingress ni les autres pods ne pourraient communiquer avec l'application. C'est le **point d'entrée réseau** interne pour les pods FastAPI.
