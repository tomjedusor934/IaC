# Explication : `.github/workflows/app-ci.yml`

## A quoi sert ce fichier ?

Ce workflow **vérifie automatiquement le code de l'application FastAPI** à chaque Pull Request. Il effectue 3 vérifications :
1. **Lint** (qualité du code Python)
2. **Tests** (les tests passent-ils ?)
3. **Build Docker** (l'image Docker se construit-elle ?)

Rien n'est déployé — c'est uniquement de la validation.

---

## Explication ligne par ligne

```yaml
name: "App CI"
```

```yaml
on:
  pull_request:
    branches: [develop, main]
    paths:
      - "app/**"
      - "helm/fastapi-app/**"
```
Se déclenche sur les PR vers `develop` ou `main`, mais uniquement si des fichiers dans `app/` ou `helm/fastapi-app/` sont modifiés.

> **Pourquoi inclure `helm/` ?** Parce que si tu changes les templates Helm de l'application, il faut aussi vérifier que tout fonctionne.

```yaml
permissions:
  contents: read
```
Ce workflow n'a besoin que de lire le code — pas besoin de WIF (on ne touche pas à GCP).

---

### Job 1 : `lint`

```yaml
  lint:
    name: "Lint (ruff)"
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install ruff
        run: pip install ruff

      - name: Run ruff linter
        run: ruff check app/

      - name: Run ruff formatter check
        run: ruff format --check app/
```

**Ruff** est un linter Python ultra-rapide (écrit en Rust). Il vérifie :
- `ruff check` : erreurs de code (variables inutilisées, imports manquants, bugs potentiels, etc.)
- `ruff format --check` : vérifie que le code est correctement formaté (comme `black` mais plus rapide)

> Le `--check` signifie « vérifie mais ne corrige pas ». Si le format est incorrect, le job échoue.

---

### Job 2 : `test`

```yaml
  test:
    name: "Tests (pytest)"
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: |
          pip install -r app/requirements.txt
          pip install -r app/requirements-test.txt

      - name: Run tests
        run: pytest app/tests/ -v --tb=short
        env:
          DATABASE_HOST: "localhost"
          JWT_SECRET_KEY: "test-secret-key-for-ci"
```

- Installe **toutes les dépendances** (prod + test)
- Lance **pytest** avec :
  - `-v` : mode verbeux (affiche chaque test individuellement)
  - `--tb=short` : tracebacks courtes en cas d'erreur
- Les variables d'environnement `DATABASE_HOST` et `JWT_SECRET_KEY` sont définies avec des valeurs de test (pas besoin d'une vraie DB — les tests utilisent SQLite en mémoire)

---

### Job 3 : `docker-build`

```yaml
  docker-build:
    name: "Docker Build (no push)"
    runs-on: ${{ vars.RUNNER_LABEL || 'ubuntu-latest' }}
    needs: [lint, test]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build Docker image (no push)
        uses: docker/build-push-action@v6
        with:
          context: ./app
          push: false
          tags: fastapi-app:test
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

- `needs: [lint, test]` : ne s'exécute que si lint ET tests passent
- `docker/setup-buildx-action` : installe Docker Buildx (version améliorée de Docker build)
- `docker/build-push-action` : construit l'image Docker
  - `push: false` : ne pousse PAS l'image vers un registry — on vérifie juste qu'elle se construit
  - `cache-from/cache-to: type=gha` : utilise le cache GitHub Actions pour accélérer les builds suivants

---

## Pourquoi ce fichier est nécessaire ?

1. **Qualité du code** : le lint attrape les erreurs de style et les bugs avant la revue
2. **Non-régression** : les tests garantissent que le nouveau code ne casse pas l'existant
3. **Buildabilité** : même si le code compile, il faut vérifier que le Dockerfile fonctionne
4. **Pipeline en cascade** : lint → test → build, chaque étape dépend de la précédente
