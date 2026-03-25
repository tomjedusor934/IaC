# Explication : `helm/fastapi-app/templates/ingress.yaml`

Ce template crée un **Ingress** — la porte d'entrée depuis Internet vers l'application.

---

## Qu'est-ce qu'un Ingress ?

Un Ingress est un objet Kubernetes qui configure le **routage HTTP/HTTPS** depuis l'extérieur vers les Services internes. Il travaille avec un **Ingress Controller** (ici NGINX) qui fait le travail réel.

Sans Ingress, l'application n'est accessible que depuis l'intérieur du cluster.

---

## Contenu

```yaml
{{- if .Values.ingress.enabled }}
```
L'Ingress n'est créé que si `ingress.enabled = true`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "fastapi-app.fullname" . }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
```
Les **annotations** sont clés. Elles configurent le comportement du contrôleur NGINX et de cert-manager :
- `cert-manager.io/cluster-issuer: "letsencrypt-prod"` : demande un certificat TLS automatiquement
- `nginx.ingress.kubernetes.io/ssl-redirect: "true"` : redirige HTTP → HTTPS
- `nginx.ingress.kubernetes.io/force-ssl-redirect: "true"` : force HTTPS même derrière un proxy

```yaml
spec:
  ingressClassName: {{ .Values.ingress.className }}
```
`nginx` : utilise le contrôleur Ingress NGINX (installé précédemment via Helm).

### TLS (HTTPS)

```yaml
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        - {{ . | quote }}
      secretName: {{ .secretName }}
    {{- end }}
```
Configure le HTTPS :
- `hosts` : le domaine pour lequel le certificat est valide
- `secretName` : le nom du Secret Kubernetes qui contiendra le certificat (créé automatiquement par cert-manager)

### Règles de routage

```yaml
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "fastapi-app.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
    {{- end }}
```
Quand une requête arrive pour le domaine spécifié avec le chemin `/` → elle est envoyée au Service sur le port 80.

`pathType: Prefix` : toutes les requêtes commençant par `/` matchent (c'est-à-dire toutes les requêtes).

---

## Flux complet

```
Utilisateur → DNS → IP du Load Balancer → NGINX Controller → Ingress rules → Service → Pod
```

---

## Pourquoi ce fichier est nécessaire ?

L'Ingress est le **seul moyen** d'exposer l'application sur Internet avec :
- Un **nom de domaine** personnalisé
- Un **certificat HTTPS** automatique
- La **redirection HTTP → HTTPS**
- Le **routage** basé sur l'URL
