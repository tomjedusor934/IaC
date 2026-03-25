# Explication : `pyproject.toml`

Ce fichier configure les **outils de qualité de code** Python utilisés dans le projet.

---

## Qu'est-ce que `pyproject.toml` ?

C'est le fichier de configuration standard pour les projets Python modernes (PEP 518/621). Il remplace les anciens `setup.cfg`, `.flake8`, `.isort.cfg`, etc. Un seul fichier pour tout configurer.

---

## Section `[tool.ruff]` — Le linter Ruff

```toml
[tool.ruff]
target-version = "py312"
line-length = 100
src = ["app"]
```

**Ruff** est un linter Python ultra-rapide (écrit en Rust). Il remplace Flake8, isort, pyupgrade et bien d'autres en un seul outil.

- `target-version = "py312"` : le code cible Python 3.12. Ruff suggèrera les syntaxes modernes disponibles
- `line-length = 100` : longueur maximale d'une ligne (100 au lieu de 79 par défaut)
- `src = ["app"]` : le code source est dans le dossier `app/`

### Les règles activées

```toml
[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors        → erreurs de style (indentation, espaces)
    "W",    # pycodestyle warnings       → avertissements de style
    "F",    # pyflakes                   → erreurs logiques (imports inutilisés, variables non définies)
    "I",    # isort                      → tri automatique des imports
    "N",    # pep8-naming                → conventions de nommage (classes en CamelCase, etc.)
    "UP",   # pyupgrade                  → suggestions pour utiliser Python moderne
    "B",    # flake8-bugbear             → détection de bugs courants
    "S",    # flake8-bandit              → détection de problèmes de sécurité
    "A",    # flake8-builtins            → détection de shadowing des built-ins
    "C4",   # flake8-comprehensions      → optimisation des listes/dicts en compréhension
    "T20",  # flake8-print               → détection de print() oublié
]
```

Chaque code-lettre active un groupe de règles. Par exemple :
- `"S"` : détecte les failles de sécurité (mots de passe en dur, SQL injection, etc.)
- `"T20"` : signale les `print()` qui ne devraient pas être en production (utiliser `logging` à la place)
- `"B"` : détecte des bugs subtils (argument mutable par défaut, etc.)

### Les règles ignorées

```toml
ignore = [
    "S105",  # hardcoded-password-string
    "S106",  # hardcoded-password-func-arg
]
```
On désactive deux règles de sécurité Bandit qui alerteraient sur les valeurs par défaut de mots de passe dans la config (comme `JWT_SECRET_KEY = "default-secret"`). Ces defaults sont nécessaires pour le développement local.

### Ignorer des règles par fichier

```toml
[tool.ruff.lint.per-file-ignores]
"app/tests/*" = ["S101"]  # Allow assert in tests
```
Dans les fichiers de test, on autorise `assert` (rule `S101`). Bandit considère `assert` comme dangereux en production (il est supprimé avec `-O`), mais c'est la base de pytest.

---

## Section `[tool.pytest.ini_options]` — Configuration pytest

```toml
[tool.pytest.ini_options]
testpaths = ["app/tests"]
asyncio_mode = "auto"
```

- `testpaths = ["app/tests"]` : indique où chercher les fichiers de test
- `asyncio_mode = "auto"` : pytest-asyncio détecte automatiquement les tests asyncio (pas besoin de décorateur `@pytest.mark.asyncio`)

---

## Pourquoi ce fichier est nécessaire ?

Il garantit la **qualité du code** :
1. **Ruff** vérifie automatiquement le style, les bugs et la sécurité lors du CI (workflow `app-ci.yml`)
2. **pytest** exécute les tests automatiquement
3. La configuration est **partagée** : tous les développeurs et le CI utilisent les mêmes règles
4. **Un seul fichier** pour toute la config → facile à maintenir
