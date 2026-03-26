Containerizing and deploying `yahoo_trending_tickers.py` to Azure

Quick steps

1. Build the Docker image locally:

```bash
docker build -t myrepo/yahoo-trending:latest .
```

2. Test locally (pass CLI args after image name):

```bash
docker run --rm myrepo/yahoo-trending:latest --region US --limit 10
```

3. Push to Azure Container Registry (ACR)

- Create a resource group and ACR (replace names):

```bash
az group create -n myResourceGroup -l westus
az acr create -n MyRegistry -g myResourceGroup --sku Basic
az acr login --name MyRegistry
```

- Tag and push the image to ACR (replace `MyRegistry`):

```bash
docker tag myrepo/yahoo-trending:latest MyRegistry.azurecr.io/yahoo-trending:latest
docker push MyRegistry.azurecr.io/yahoo-trending:latest
```

4. Deploy to Azure Container Instances (ACI)

```bash
az container create -g myResourceGroup -n yahoo-trending \
  --image MyRegistry.azurecr.io/yahoo-trending:latest \
  --cpu 1 --memory 1 \
  --registry-login-server MyRegistry.azurecr.io \
  --restart-policy OnFailure
```

5. Deploy as a HTTP service (recommended)

- Instead of ACI, deploy to Azure Container Apps or Azure Web App for Containers to expose an HTTP endpoint at `/trending`.

- Example: create a Container App (requires the Azure CLI extension `containerapp`):

```bash
# login & set subscription
az login
az account set -s <subscription-id>

# create resource group if not done
az group create -n myResourceGroup -l eastus

# create container apps environment (once)
az containerapp env create -n myEnv -g myResourceGroup -l eastus

# create the container app (example)
az containerapp create -g myResourceGroup -n yahoo-trending-app \
  --image MyRegistry.azurecr.io/yahoo-trending:latest \
  --environment myEnv --ingress external --target-port 8080
```

6. Create an Azure Logic App to schedule and push to GitHub

- In the Azure Portal, create a Logic App (Consumption or Standard). Use the Logic App Designer to build a workflow:
  - Trigger: Recurrence — set Frequency: Day, Interval: 1, At these hours/minutes: 15:55, Time zone: `Eastern Standard Time` (or `America/New_York`).
  - Action: HTTP — GET `https://<your-container-app-host>/trending?region=US&limit=20` (this will return the JSON payload).
  - Action: GitHub — Choose `Create or update file` (you'll be prompted to sign in and authorize the connector).
    - Repository: select your repo
    - File path: path/to/trending.json
    - File content: use the body from the HTTP action
    - Commit message: `Automated trending update`

- Save the Logic App. It will run daily at 3:55pm Eastern and push the latest JSON into your GitHub repo.

Notes:
- Logic Apps will handle the GitHub OAuth flow; no PAT stored in code.
- If your container app requires authentication, you can secure it and add an HTTP action with managed identity or a client secret.
- You can also add error handling in the Logic App: on failure, send yourself an email or retry.

QuantConnect integration
- Point your QuantConnect job to read the JSON from your repository (raw.githubusercontent.com URL) or from Azure Blob Storage. If you want the file stored in Blob Storage instead, change the Logic App flow: call the HTTP service, then use the Azure Blob Storage connector to upload the file, then (optionally) push to GitHub.


Notes and alternatives
- You can also deploy the image to Azure Web App for Containers or AKS.
- Replace `MyRegistry`, `myResourceGroup`, and other placeholders with your values.
- If the image is rate-limited by Yahoo, consider scheduling runs less frequently or using an App Service with caching.

Automation script
-----------------

I included a helper script `codex-projects/deploy_azure.sh` that:

- Creates the resource group and an Azure Container Registry (ACR) if missing.
- Builds and pushes the Docker image to ACR.
- Creates a Container Apps environment and deploys the container app.

Usage:

```bash
chmod +x codex-projects/deploy_azure.sh
./codex-projects/deploy_azure.sh <resource-group> <location> <acr-name> <image-name> <tag> <env-name> <app-name>
# example:
./codex-projects/deploy_azure.sh myResourceGroup eastus myregistry yahoo-trending latest myEnv yahoo-trending-app
```

After the script finishes it prints the container app host. Use that value when creating the Logic App workflow.

Logic App workflow template
---------------------------

See `codex-projects/templates/logicapp_workflow.json` — import this definition into the Logic App Designer (Code view) and sign in to the GitHub connector when prompted. The workflow:

- Triggers daily at 3:55 PM Eastern.
- Calls `https://<your-container-host>/trending?region=US&limit=20`.
- Uses the GitHub connector `Create or update file` action to write `trending.json` into your repository.

