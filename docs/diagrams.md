# Infrastructure Architecture Diagram

## Main Architecture

```mermaid
graph TB
    subgraph Internet["Internet"]
        DEV["Developer"]
        GH["GitHub<br/>Repository"]
        DNS["DNS<br/>HERE_APP_DOMAIN"]
    end

    subgraph GCP["GCP Project"]
        subgraph VPC["VPC: gke-vpc"]
            subgraph Subnet["Subnet: gke-subnet (10.0.0.0/20)"]
                subgraph GKE["GKE Cluster (Private, Dataplane V2)"]
                    subgraph NS_INGRESS["Namespace: ingress-nginx"]
                        NGINX["NGINX Ingress<br/>Controller"]
                        CM["cert-manager"]
                    end
                    subgraph NS_APP["Namespace: app"]
                        FASTAPI["FastAPI Pods<br/>(HPA 2-10)"]
                        PROXY["Cloud SQL<br/>Auth Proxy<br/>(sidecar)"]
                        SA_K8S["K8s ServiceAccount<br/>(Workload Identity)"]
                    end
                    subgraph NS_RUNNERS["Namespace: runners"]
                        ARC["ARC Controller"]
                        RUNNERS["Self-Hosted<br/>Runner Pods<br/>(scale 0-5)"]
                    end
                    subgraph NS_MON["Namespace: monitoring"]
                        PROM["Prometheus"]
                        GRAF["Grafana"]
                        AM["Alertmanager"]
                    end
                end
            end

            NAT["Cloud NAT"]
            ROUTER["Cloud Router"]
            PSA["Private Service Access"]
        end

        AR["Artifact Registry<br/>(Docker)"]
        SM["Secret Manager"]

        subgraph CSQL["Cloud SQL"]
            PG["PostgreSQL 15<br/>(Private IP)"]
        end

        subgraph WIF["Workload Identity Federation"]
            POOL["WIF Pool"]
            OIDC["OIDC Provider<br/>(GitHub)"]
            SA_WIF["GCP Service Account<br/>(CI/CD)"]
        end

        subgraph IAM["IAM"]
            SA_APP["App Service Account<br/>(cloudsql.client)"]
        end

        BUCKET["GCS Bucket<br/>(Terraform State)"]
    end

    DEV -->|"git push"| GH
    GH -->|"OIDC Token"| WIF
    WIF -->|"Short-lived credentials"| SA_WIF
    SA_WIF -->|"Deploy"| GKE
    SA_WIF -->|"Push image"| AR

    GH -->|"Webhook"| ARC
    ARC -->|"Scale"| RUNNERS

    DNS -->|"HTTPS"| NGINX
    NGINX -->|"Route"| FASTAPI
    FASTAPI --- PROXY
    PROXY -->|"Private IP"| PG
    SA_K8S -.->|"Workload Identity"| SA_APP
    SA_APP -.->|"Access"| SM

    GKE --> NAT
    NAT --> ROUTER
    PSA --> CSQL

    PROM -->|"Scrape"| FASTAPI
    GRAF -->|"Query"| PROM

    AR -->|"Pull image"| GKE

    classDef gcp fill:#4285F4,stroke:#333,color:#fff
    classDef k8s fill:#326CE5,stroke:#333,color:#fff
    classDef app fill:#34A853,stroke:#333,color:#fff
    classDef mon fill:#FBBC04,stroke:#333,color:#000
    classDef sec fill:#EA4335,stroke:#333,color:#fff

    class GCP,VPC,Subnet gcp
    class GKE,NS_INGRESS,NS_APP,NS_RUNNERS,NS_MON k8s
    class FASTAPI,PROXY app
    class PROM,GRAF,AM mon
    class WIF,IAM,SM sec
```

## CI/CD Pipeline Flow

```mermaid
flowchart LR
    subgraph PR["Pull Request"]
        TF_CI["terraform-ci<br/>fmt + validate + plan"]
        APP_CI["app-ci<br/>lint + test + build"]
    end

    subgraph DEV_DEPLOY["Push to develop"]
        TF_DEV["terraform-apply-dev<br/>Apply infra"]
        APP_DEV["app-deploy-dev<br/>Build + Push + Helm upgrade"]
    end

    subgraph PRD_DEPLOY["Push to main / Tag"]
        TF_PRD["terraform-apply-prd<br/>Apply infra"]
        APP_PRD["app-deploy-prd<br/>Build + Push + Helm upgrade"]
    end

    PR --> DEV_DEPLOY
    DEV_DEPLOY --> PRD_DEPLOY

    classDef ci fill:#FBBC04,stroke:#333,color:#000
    classDef dev fill:#34A853,stroke:#333,color:#fff
    classDef prd fill:#EA4335,stroke:#333,color:#fff

    class TF_CI,APP_CI ci
    class TF_DEV,APP_DEV dev
    class TF_PRD,APP_PRD prd
```

## GitFlow Branching Strategy

```mermaid
gitgraph
    commit id: "init"
    branch develop
    checkout develop
    commit id: "infra-setup"
    branch feature/vpc
    checkout feature/vpc
    commit id: "add-vpc-module"
    checkout develop
    merge feature/vpc
    branch feature/gke
    checkout feature/gke
    commit id: "add-gke-module"
    checkout develop
    merge feature/gke
    branch feature/app
    checkout feature/app
    commit id: "add-fastapi-app"
    commit id: "add-helm-chart"
    checkout develop
    merge feature/app
    checkout main
    merge develop tag: "v1.0.0"
    checkout develop
    branch feature/monitoring
    checkout feature/monitoring
    commit id: "add-monitoring"
    checkout develop
    merge feature/monitoring
    checkout main
    merge develop tag: "v1.1.0"
```
