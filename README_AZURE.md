Containerizing and deploying `yahoo_trending_tickers.py` to Azure

This repo now includes automation scripts to deploy:

1) A **Container App** hosting `/trending`.
2) A **Logic App** that runs **every weekday (Monday-Friday) at 3:55 PM Eastern** and commits JSON output to GitHub.

## Prerequisites

- Azure CLI installed and logged in (`az login`).
- Docker installed and running.
- Permission to create Azure resources.
- A GitHub Personal Access Token (PAT) with `repo` scope.

## 1) Deploy the container app

```bash
chmod +x ./deploy_azure.sh
./deploy_azure.sh <resource-group> <location> <acr-name> <image-name> <tag> <env-name> <app-name>
```

Example:

```bash
./deploy_azure.sh myResourceGroup eastus myregistry yahoo-trending latest myEnv yahoo-trending-app
```

When it completes, the script prints a host like:

```text
https://<your-container-app-host>
```

Use that host in the next step.

## 2) Deploy the weekday scheduler + GitHub writer (Logic App)

```bash
chmod +x ./deploy_logicapp.sh
./deploy_logicapp.sh <resource-group> <location> <logic-app-name> <container-url> <repo-owner> <repo-name> <github-pat> [file-path]
```

Example:

```bash
./deploy_logicapp.sh \
  myResourceGroup \
  eastus \
  yahoo-trending-weekday-export \
  https://myapp.eastus.azurecontainerapps.io \
  your-github-username \
  your-repo \
  ghp_xxxREDACTEDxxx \
  data/trending.json
```

This deploys `templates/logicapp_arm_template.json`, which:

- Triggers on weekdays at 3:55 PM ET.
- Calls `GET <container-url>/trending?region=US&limit=20`.
- Commits the JSON response to your GitHub repository.

## Template files

- `templates/logicapp_workflow.json` - direct Logic App workflow definition.
- `templates/logicapp_arm_template.json` - ARM deployment template for workflow + GitHub connection.


## Troubleshooting

- **Error:** `failed to build: unable to prepare context: path "codex-projects" not found`
  - Cause: You are using an older copy of `deploy_azure.sh` that hard-coded `codex-projects` in the Docker build path.
  - Fix: Pull latest repo changes and rerun `./deploy_azure.sh ...`. The updated script resolves paths from its own location and prints the exact docker build command it is using.

- **Error:** `The workflow parameters '$connections' are not valid...`
  - Cause: older ARM template missing definition-level `$connections` declaration.
  - Fix: pull latest repo and redeploy with `./deploy_logicapp.sh ...`.


- **Need deployment operation details**
  - Use the current Azure CLI syntax:
    ```bash
    az deployment operation group list \
      --resource-group myResourceGroup \
      --name logicapp_arm_template \
      -o table
    ```
  - If this command is unavailable, update Azure CLI (`az upgrade`).

## Optional: test your endpoint

```bash
curl "https://<your-container-app-host>/trending?region=US&limit=5"
```

## Notes

- Keep your GitHub PAT secure; prefer secret management in production.
- Logic App schedule timezone is set to `Eastern Standard Time` to maintain 3:55 PM ET behavior.
- If you want a different output file path, pass the optional `[file-path]` argument.
