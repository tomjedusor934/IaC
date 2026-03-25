# 📚 Ordre de Lecture Recommandé pour Débutant

## Pourquoi un ordre de lecture ?

Les fichiers du projet sont interdépendants. Lire dans le mauvais ordre, c'est comme lire le chapitre 10 d'un livre sans avoir lu les 9 premiers : on ne comprend rien. Cet ordre est conçu pour construire ta compréhension **brique par brique**.

---

## 🗺️ Vue d'ensemble en 5 phases

```
Phase 1 : Comprendre les fondations (Terraform + Cloud)
Phase 2 : Comprendre le réseau et la base de données
Phase 3 : Comprendre Kubernetes et le déploiement
Phase 4 : Comprendre le CI/CD (GitHub Actions)
Phase 5 : Comprendre le monitoring
```

---

## Phase 1 — Les Fondations (Terraform & IAM)

**Objectif** : Comprendre comment on décrit une infrastructure en code.

| # | Fichier | Pourquoi en premier |
|---|---------|-------------------|
| 1 | `pyproject-toml.md` | Le plus simple. C'est juste la config de l'app Python. Ça te met en confiance. |
| 2 | `env-dev-backend.md` | Comprendre où Terraform stocke son état (le "cerveau" de Terraform). |
| 3 | `env-dev-variables.md` | Comprendre le concept de variables dans Terraform. |
| 4 | `env-dev-tfvars.md` | Comprendre comment on donne des valeurs aux variables. |
| 5 | `env-dev-outputs.md` | Comprendre comment Terraform nous "parle" après avoir créé des ressources. |
| 6 | `env-dev-main.md` | Le fichier central qui appelle tous les modules. Tu comprendras la structure globale. |
| 7 | `env-prd.md` | Voir les différences dev/prd. Court car c'est la même structure. |

### 🎓 Ressources pour cette phase

**Terraform (indispensable à comprendre en premier)**
- 🎥 [Terraform en 15 minutes - TechWorld with Nana](https://www.youtube.com/watch?v=l5k1ai_GBDE) (EN, 15 min) — La meilleure intro rapide
- 🎥 [Terraform Full Course - FreeCodeCamp](https://www.youtube.com/watch?v=SLB_c_ayRMo) (EN, 2h30) — Cours complet gratuit
- 🎥 [Terraform pour les débutants - Cocadmin](https://www.youtube.com/watch?v=4QMmSJoRMSI) (FR, 30 min) — En français
- 📖 [Documentation officielle Terraform](https://developer.hashicorp.com/terraform/tutorials) — Les tutos "Get Started" sont excellents

---

## Phase 2 — Le Réseau et la Base de Données

**Objectif** : Comprendre comment les machines communiquent entre elles.

| # | Fichier | Pourquoi dans cet ordre |
|---|---------|------------------------|
| 8 | `module-vpc.md` | Le réseau est la base de TOUT. Sans réseau, rien ne communique. |
| 9 | `module-cloudsql.md` | La base de données. Elle vit dans le réseau qu'on vient de créer. |
| 10 | `module-iam.md` | Les permissions. Qui a le droit de faire quoi. |
| 11 | `module-wif.md` | L'authentification sans mot de passe entre GitHub et GCP. |
| 12 | `module-artifact-registry.md` | Le stockage d'images Docker (simple, petit module). |

### 🎓 Ressources pour cette phase

**Réseau / VPC**
- 🎥 [Computer Networking Full Course - Kunal Kushwaha](https://www.youtube.com/watch?v=IPvYjXCsTg8) (EN, 5h) — Si tu veux VRAIMENT comprendre le réseau
- 🎥 [VPC Explained - TechWorld with Nana](https://www.youtube.com/watch?v=bGDMeD6kOz0) (EN, 10 min) — Juste le VPC
- 🎥 [Le réseau pour les nuls - Cookie connecté](https://www.youtube.com/watch?v=JlJVJimnMco) (FR, 15 min) — En français, très clair

**Cloud SQL / Bases de données**
- 🎥 [SQL expliqué en 100 secondes - Fireship](https://www.youtube.com/watch?v=zsjvFFKOm3c) (EN, 2 min)
- 🎥 [Cloud SQL Google - Google Cloud Tech](https://www.youtube.com/watch?v=VUV5-Gz1mOU) (EN, 5 min)

**IAM / Sécurité**
- 🎥 [GCP IAM Explained - Google Cloud Tech](https://www.youtube.com/watch?v=CELp81Jo1C8) (EN, 10 min)
- 🎥 [Workload Identity Federation - Google Cloud Tech](https://www.youtube.com/watch?v=ZgCfRjEkpDw) (EN, 15 min) — Exactement ce qu'on utilise

---

## Phase 3 — Kubernetes et le Déploiement

**Objectif** : Comprendre comment l'application tourne dans le cluster.

| # | Fichier | Pourquoi dans cet ordre |
|---|---------|------------------------|
| 13 | `module-gke.md` | Le cluster Kubernetes lui-même. Le "terrain" où tout va tourner. |
| 14 | `helm-chart-yaml.md` | Qu'est-ce qu'un chart Helm ? Les métadonnées. |
| 15 | `helm-helpers.md` | Les fonctions réutilisables dans les templates Helm. |
| 16 | `helm-values-yaml.md` | Les valeurs par défaut du chart. |
| 17 | `helm-values-dev.md` | Les surcharges pour dev et prd. |
| 18 | `helm-configmap.md` | Comment passer de la configuration aux pods. |
| 19 | `helm-secret.md` | Comment gérer les secrets dans Kubernetes. |
| 20 | `helm-serviceaccount.md` | L'identité des pods dans le cluster. |
| 21 | `helm-deployment.md` | ⭐ Le plus important : comment l'app est déployée. |
| 22 | `helm-service.md` | Comment exposer l'app à l'intérieur du cluster. |
| 23 | `helm-ingress.md` | Comment exposer l'app à l'extérieur (internet). |
| 24 | `helm-hpa.md` | Le scaling automatique des pods. |
| 25 | `helm-pdb.md` | La protection contre les interruptions. |
| 26 | `helm-servicemonitor.md` | Le lien entre l'app et le monitoring. |

### 🎓 Ressources pour cette phase

**Kubernetes (le plus gros morceau à comprendre)**
- 🎥 [Kubernetes en 100 secondes - Fireship](https://www.youtube.com/watch?v=PziYflu8cB8) (EN, 2 min) — Commencer ici !
- 🎥 [Kubernetes Crash Course - TechWorld with Nana](https://www.youtube.com/watch?v=s_o8dwzRlu4) (EN, 1h) — ⭐ LA vidéo à regarder absolument
- 🎥 [Kubernetes Full Course - FreeCodeCamp](https://www.youtube.com/watch?v=d6WC5n9G_sM) (EN, 3h30)
- 🎥 [Kubernetes pour les débutants - Xavki](https://www.youtube.com/playlist?list=PLn6POgpklwWqfzaosSgX2XEKpse5VY2v5) (FR, playlist) — En français, très détaillé

**Helm**
- 🎥 [Helm expliqué - TechWorld with Nana](https://www.youtube.com/watch?v=-ykwb1d0DXU) (EN, 30 min) — ⭐ Parfait pour comprendre Helm
- 🎥 [Helm en 10 minutes - IBM Technology](https://www.youtube.com/watch?v=fy8SHvNZGeE) (EN, 10 min)
- 📖 [Documentation officielle Helm](https://helm.sh/docs/) — La référence

**Docker (prérequis pour Kubernetes)**
- 🎥 [Docker en 100 secondes - Fireship](https://www.youtube.com/watch?v=Gjnup-PuquQ) (EN, 2 min)
- 🎥 [Docker Crash Course - TechWorld with Nana](https://www.youtube.com/watch?v=pg19Z8LL06w) (EN, 1h)
- 🎥 [Docker pour les débutants - Cocadmin](https://www.youtube.com/watch?v=SXB6KJ4u5vg) (FR, 45 min)

---

## Phase 4 — CI/CD (GitHub Actions)

**Objectif** : Comprendre le pipeline automatisé de bout en bout.

| # | Fichier | Pourquoi dans cet ordre |
|---|---------|------------------------|
| 27 | `workflow-terraform-ci.md` | La validation automatique (le plus simple des workflows). |
| 28 | `workflow-terraform-apply-dev.md` | Le déploiement Terraform en dev. |
| 29 | `workflow-terraform-apply-prd.md` | Le déploiement Terraform en prd (voir les différences). |
| 30 | `workflow-app-ci.md` | La CI de l'application (tests, lint, build). |
| 31 | `workflow-app-deploy-dev.md` | Le déploiement de l'app en dev. |
| 32 | `workflow-app-deploy-prd.md` | Le déploiement de l'app en prd. |
| 33 | `workflow-destroy.md` | La destruction manuelle de l'infra. |

### 🎓 Ressources pour cette phase

**GitHub Actions**
- 🎥 [GitHub Actions en 100 secondes - Fireship](https://www.youtube.com/watch?v=cP0I9w2coGU) (EN, 2 min)
- 🎥 [GitHub Actions Tutorial - TechWorld with Nana](https://www.youtube.com/watch?v=R8_veQiYBjI) (EN, 1h) — ⭐ Très recommandé
- 🎥 [GitHub Actions - Grafikart](https://www.youtube.com/watch?v=O-F5MnPMiCc) (FR, 30 min) — En français
- 📖 [Documentation officielle GitHub Actions](https://docs.github.com/en/actions)

**CI/CD Général**
- 🎥 [CI/CD expliqué - IBM Technology](https://www.youtube.com/watch?v=scEDHsr3APg) (EN, 8 min)
- 🎥 [GitFlow expliqué - Atlassian](https://www.youtube.com/watch?v=1SXpE08hvGs) (EN, 5 min)

---

## Phase 5 — Monitoring

**Objectif** : Comprendre comment surveiller ce qu'on a construit.

| # | Fichier | Pourquoi dans cet ordre |
|---|---------|------------------------|
| 34 | `monitoring-values.md` | La configuration de Prometheus + Grafana. |
| 35 | `monitoring-alerts.md` | Les alertes automatiques. |
| 36 | `monitoring-grafana-dashboard.md` | Les dashboards visuels. |

### 🎓 Ressources pour cette phase

**Prometheus & Grafana**
- 🎥 [Prometheus expliqué en 15 minutes - TechWorld with Nana](https://www.youtube.com/watch?v=h4Sl21AKiDg) (EN, 15 min) — ⭐ Excellent
- 🎥 [Grafana Tutorial - TechWorld with Nana](https://www.youtube.com/watch?v=lILY8eSspEo) (EN, 20 min)
- 🎥 [Monitoring avec Prometheus et Grafana - Xavki](https://www.youtube.com/playlist?list=PLn6POgpklwWrcA1AvJurJJt3ORcoNwyBs) (FR, playlist)

---

## 🏆 Les 5 vidéos à regarder EN PREMIER si tu ne devais en voir que 5

| # | Vidéo | Durée | Pourquoi |
|---|-------|-------|----------|
| 1 | [Docker Crash Course - Nana](https://www.youtube.com/watch?v=pg19Z8LL06w) | 1h | Prérequis pour tout le reste |
| 2 | [Kubernetes Crash Course - Nana](https://www.youtube.com/watch?v=s_o8dwzRlu4) | 1h | Le cœur du projet |
| 3 | [Terraform en 15 min - Nana](https://www.youtube.com/watch?v=l5k1ai_GBDE) | 15 min | L'outil IaC principal |
| 4 | [Helm expliqué - Nana](https://www.youtube.com/watch?v=-ykwb1d0DXU) | 30 min | Comment on déploie sur K8s |
| 5 | [GitHub Actions - Nana](https://www.youtube.com/watch?v=R8_veQiYBjI) | 1h | Le pipeline CI/CD |

> 💡 **Astuce** : La chaîne **TechWorld with Nana** est probablement la meilleure source gratuite pour apprendre DevOps. Presque tout ce qu'on utilise dans ce projet y est expliqué.

---

## ⏱️ Estimation du temps de lecture

| Phase | Nombre de fichiers | Temps estimé (lecture) | Temps estimé (avec vidéos) |
|-------|-------------------|----------------------|---------------------------|
| Phase 1 | 7 fichiers | 45 min | 3h |
| Phase 2 | 5 fichiers | 40 min | 2h |
| Phase 3 | 14 fichiers | 1h30 | 4h |
| Phase 4 | 7 fichiers | 1h | 2h |
| Phase 5 | 3 fichiers | 30 min | 1h30 |
| **Total** | **36 fichiers** | **~4h15** | **~12h30** |

---

## 💡 Conseils de lecture

1. **Ne saute pas les phases.** Chaque phase s'appuie sur la précédente.
2. **Regarde les vidéos avant de lire les fichiers.** Les vidéos donnent le contexte, les fichiers donnent le détail.
3. **Prends des notes.** Écris dans tes propres mots ce que tu comprends.
4. **Teste au fur et à mesure.** Après la Phase 1, essaie de lancer `terraform init` et `terraform plan` toi-même.
5. **Relis après avoir testé.** La deuxième lecture sera beaucoup plus claire.
6. **N'essaie pas de tout comprendre d'un coup.** C'est normal de ne pas tout saisir au premier passage. Reviens plus tard.

---

## 🔗 Ressources complémentaires utiles

| Sujet | Lien | Type |
|-------|------|------|
| Linux basics | [Linux Journey](https://linuxjourney.com/) | Site interactif |
| YAML syntax | [Learn YAML in 5 min](https://www.codeproject.com/Articles/1214409/Learn-YAML-in-five-minutes) | Article |
| Git basics | [Git - the simple guide](https://rogerdudler.github.io/git-guide/) | Site |
| GCP Free Tier | [Google Cloud Free Tier](https://cloud.google.com/free) | Documentation |
| Terraform Registry | [registry.terraform.io](https://registry.terraform.io/) | Documentation |
| Artifact Hub (Helm) | [artifacthub.io](https://artifacthub.io/) | Documentation |
| Kubernetes Docs | [kubernetes.io/docs](https://kubernetes.io/docs/home/) | Documentation |