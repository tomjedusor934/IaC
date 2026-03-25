# ==============================================================================
# DEV Environment - terraform.tfvars
# ==============================================================================
# Replace placeholder values with your actual configuration.
# Sensitive values should be passed via environment variables or CI/CD secrets:
#   TF_VAR_github_app_id, TF_VAR_github_app_installation_id,
#   TF_VAR_github_app_private_key, TF_VAR_jwt_secret_key

project_id  = "iac-dev-491314"
region      = "europe-west1"
environment = "dev"

github_owner = "tomjedusor934"
github_repo  = "IaC"

app_image_tag = "latest"
