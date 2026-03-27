#!/usr/bin/env bash
set -euo pipefail

# Deploys the Logic App ARM template so it runs Monday-Friday at 3:55 PM ET,
# calls the /trending endpoint, and commits JSON output to GitHub.

RG=${1:?Usage: ./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-token> [file-path]}
LOCATION=${2:?Usage: ./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-token> [file-path]}
LOGIC_APP_NAME=${3:?Usage: ./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-token> [file-path]}
CONTAINER_URL=${4:?Usage: ./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-token> [file-path]}
REPO_OWNER=${5:?Usage: ./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-token> [file-path]}
REPO_NAME=${6:?Usage: ./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-token> [file-path]}
GITHUB_TOKEN=${7:?Usage: ./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-token> [file-path]}
FILE_PATH=${8:-data/trending.json}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deploying Logic App '$LOGIC_APP_NAME' in resource group '$RG'..."

az group create -n "$RG" -l "$LOCATION" >/dev/null

az deployment group create \
  --resource-group "$RG" \
  --template-file "$SCRIPT_DIR/templates/logicapp_arm_template.json" \
  --parameters \
    logicAppName="$LOGIC_APP_NAME" \
    location="$LOCATION" \
    containerUrl="$CONTAINER_URL" \
    repoOwner="$REPO_OWNER" \
    repoName="$REPO_NAME" \
    filePath="$FILE_PATH" \
    githubToken="$GITHUB_TOKEN"

echo "Done. Logic App '$LOGIC_APP_NAME' now runs weekdays at 3:55 PM Eastern and writes to ${REPO_OWNER}/${REPO_NAME}:${FILE_PATH}."
