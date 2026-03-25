# GitFlow Branching Strategy

## Branch Structure

```
main (production)
  └── develop (integration)
       ├── feature/<name>
       ├── fix/<name>
       └── hotfix/<name>
```

## Branch Roles

| Branch | Purpose | Deploys to | Protected |
|--------|---------|------------|-----------|
| `main` | Production-ready code | **prd** | Yes — requires PR + approval |
| `develop` | Integration branch | **dev** | Yes — requires PR |
| `feature/*` | New features | — (CI only) | No |
| `fix/*` | Bug fixes | — (CI only) | No |
| `hotfix/*` | Urgent production fixes | — (CI only) | No |

## Workflow

### Feature Development

```
1. git checkout develop
2. git checkout -b feature/my-feature
3. # ... make changes, commit ...
4. git push origin feature/my-feature
5. # Open PR → develop (triggers CI: lint, test, plan)
6. # Merge PR → develop (triggers deploy to dev)
```

### Production Release

```
1. git checkout develop
2. git pull origin develop
3. # Open PR: develop → main
4. # Review + approve
5. # Merge → main (triggers terraform-apply-prd)
6. git tag v1.x.0
7. git push origin v1.x.0  (triggers app-deploy-prd)
```

### Hotfix

```
1. git checkout main
2. git checkout -b hotfix/critical-fix
3. # ... fix + commit ...
4. git push origin hotfix/critical-fix
5. # Open PR → main (triggers CI)
6. # Merge → main + tag → deploy to prd
7. # Backport: cherry-pick or merge into develop
```

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add task filtering endpoint
fix: resolve database connection pool exhaustion
docs: update infrastructure diagram
ci: add Terraform plan caching
chore: upgrade FastAPI to 0.115.x
```

## Tag Convention

Semantic versioning: `v<major>.<minor>.<patch>`

- `v1.0.0` — initial release
- `v1.1.0` — new feature
- `v1.1.1` — bug fix

Tags on `main` trigger the production app deployment workflow.
