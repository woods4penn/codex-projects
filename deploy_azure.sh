#!/usr/bin/env bash
set -euo pipefail

# Deploy helper: creates ACR, builds & pushes image, creates Container Apps environment
# and deploys the container. It prints the container app URL for wiring into Logic App.

RG=${1:-myResourceGroup}
LOCATION=${2:-eastus}
ACR_NAME=${3:-myregistry}
IMAGE_NAME=${4:-yahoo-trending}
TAG=${5:-latest}
APP_ENV=${6:-myEnv}
APP_NAME=${7:-yahoo-trending-app}

echo "Using resource group: $RG, location: $LOCATION"

echo "1) Create resource group"
az group create -n "$RG" -l "$LOCATION"

echo "2) Create ACR (if missing)"
az acr create -n "$ACR_NAME" -g "$RG" --sku Basic --admin-enabled true || true

ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"

echo "3) Build Docker image and push to ACR"
docker build -t "$ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG" -f codex-projects/Dockerfile codex-projects
az acr login --name "$ACR_NAME"
docker push "$ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG"

echo "4) Create Container Apps environment (if missing)"
az provider register --namespace Microsoft.Web || true
az containerapp env create -g "$RG" -n "$APP_ENV" -l "$LOCATION" || true

echo "5) Retrieve ACR credentials"
ACR_USER=$(az acr credential show -n "$ACR_NAME" -g "$RG" --query username -o tsv)
ACR_PASS=$(az acr credential show -n "$ACR_NAME" -g "$RG" --query "passwords[0].value" -o tsv)

echo "6) Deploy Container App"
az containerapp create \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --environment "$APP_ENV" \
  --image "$ACR_LOGIN_SERVER/$IMAGE_NAME:$TAG" \
  --ingress external \
  --target-port 8080 \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username "$ACR_USER" \
  --registry-password "$ACR_PASS" \
  --cpu 0.5 --memory 1.0 || true

echo "7) Get container app URL"
CONTAINER_URL=$(az containerapp show -g "$RG" -n "$APP_NAME" --query properties.configuration.ingress.fqdn -o tsv)
if [ -z "$CONTAINER_URL" ]; then
  echo "Failed to retrieve container app URL. Check deployment logs." >&2
  exit 1
fi

echo "Container app available at: https://$CONTAINER_URL"

echo
echo "Now you can create a Logic App that calls: https://$CONTAINER_URL/trending?region=US&limit=20"
echo "See codex-projects/templates/logicapp_workflow.json for a workflow you can import into Logic App Designer."
