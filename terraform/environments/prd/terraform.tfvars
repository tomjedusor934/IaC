# ==============================================================================
# PRD Environment - terraform.tfvars
# ==============================================================================
# Replace placeholder values with your actual configuration.
# Sensitive values should be passed via environment variables or CI/CD secrets:
#   TF_VAR_github_app_id, TF_VAR_github_app_installation_id,
#   TF_VAR_github_app_private_key, TF_VAR_jwt_secret_key

project_id  = "HERE_GCP_PROJECT_ID_PRD"
region      = "europe-west1"
environment = "prd"

github_owner = "HERE_GITHUB_OWNER"
github_repo  = "HERE_GITHUB_REPO_NAME"

app_image_tag = "latest"
