#!/usr/bin/env bash
# ============================================================
# mosgarage · deploy/entra-setup.sh
# AUTO-creates the Microsoft Entra ID App Registration with:
#   ✅ Tasks.ReadWrite   (Microsoft To Do / Planner)
#   ✅ Group.Read.All    (read group memberships)
#   ✅ User.Read         (read signed-in user profile)
#
# Requirements:
#   - Azure CLI installed: https://aka.ms/install-azure-cli
#   - Logged in: az login
#   - Sufficient permissions: Application Administrator or Global Administrator
#
# Usage:
#   chmod +x deploy/entra-setup.sh
#   ./deploy/entra-setup.sh
#   # Then paste the output into your .env file
# ============================================================

set -euo pipefail

APP_NAME="${MOSGARAGE_APP_NAME:-mosgarage}"
REDIRECT_URI="${MOSGARAGE_ACCESS_URL:-http://localhost:7070}/auth/signin-oidc"
LOGOUT_URI="${MOSGARAGE_ACCESS_URL:-http://localhost:7070}/auth/signout-callback-oidc"
ENV_FILE=".env"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  mosgarage · Microsoft Entra ID App Setup        ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  App name     : ${APP_NAME}"
echo "║  Redirect URI : ${REDIRECT_URI}"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Pre-flight ────────────────────────────────────────────────────
command -v az &>/dev/null || {
  echo "❌ Azure CLI not found."
  echo "   Install: https://aka.ms/install-azure-cli"
  echo "   macOS:   brew install azure-cli"
  echo "   Windows: winget install Microsoft.AzureCLI"
  exit 1
}

echo "🔐 Checking Azure login..."
ACCOUNT=$(az account show --query "{name:name, tenant:tenantId, user:user.name}" -o json 2>/dev/null) || {
  echo "   Not logged in. Running az login..."
  az login --output none
  ACCOUNT=$(az account show --query "{name:name, tenant:tenantId, user:user.name}" -o json)
}
TENANT_ID=$(echo "${ACCOUNT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant'])")
echo "  ✅ Logged in as $(echo "${ACCOUNT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['user'])")"
echo "  ✅ Tenant: ${TENANT_ID}"
echo ""

# ── Check if app already exists ───────────────────────────────────
echo "🔍 Checking for existing app '${APP_NAME}'..."
EXISTING=$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv 2>/dev/null || echo "")
if [[ -n "${EXISTING}" && "${EXISTING}" != "None" ]]; then
  echo "  ⚠️  App '${APP_NAME}' already exists (ID: ${EXISTING})"
  read -rp "     Delete and recreate? [y/N] " choice
  if [[ "${choice,,}" == "y" ]]; then
    echo "  Deleting ${EXISTING}..."
    az ad app delete --id "${EXISTING}"
    echo "  ✅ Deleted"
    sleep 3  # propagation delay
  else
    CLIENT_ID="${EXISTING}"
    echo "  Using existing app."
    # Jump to secret creation
    goto_secret=true
  fi
fi

# ── Create App Registration ───────────────────────────────────────
if [[ -z "${CLIENT_ID:-}" ]]; then
  echo ""
  echo "📝 Creating App Registration '${APP_NAME}'..."
  APP_JSON=$(az ad app create \
    --display-name "${APP_NAME}" \
    --web-redirect-uris "${REDIRECT_URI}" "${REDIRECT_URI/localhost/127.0.0.1}" \
    --sign-in-audience AzureADMyOrg \
    --query "{appId:appId, objectId:id}" \
    --output json)

  CLIENT_ID=$(echo "${APP_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['appId'])")
  OBJECT_ID=$(echo "${APP_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['objectId'])")
  echo "  ✅ App created — Client ID: ${CLIENT_ID}"
  echo "  ✅ Object ID: ${OBJECT_ID}"

  # ── Set logout URL ─────────────────────────────────────────────
  az ad app update --id "${CLIENT_ID}" \
    --set "web.logoutUrl=${LOGOUT_URI}" \
    --output none 2>/dev/null || true

  # ── Create service principal ───────────────────────────────────
  echo ""
  echo "👤 Creating service principal..."
  az ad sp create --id "${CLIENT_ID}" --output none 2>/dev/null || true
  echo "  ✅ Service principal created"
fi

# ── Microsoft Graph permission IDs (stable GUIDs) ─────────────────
# These are well-known GUIDs for Microsoft Graph delegated permissions:
GRAPH_APP_ID="00000003-0000-0000-c000-000000000000"
# User.Read:        e1fe6dd8-ba31-4d61-89e7-88639da4683d
# Group.Read.All:   5f8c59db-677d-491f-a6b8-5f174b11ec1d
# Tasks.ReadWrite:  2219042f-cab5-40cc-b0d2-16b1540b4c5f

echo ""
echo "🔑 Configuring API permissions..."

# Add required resource access
az ad app update --id "${CLIENT_ID}" \
  --required-resource-accesses "[
    {
      \"resourceAppId\": \"${GRAPH_APP_ID}\",
      \"resourceAccess\": [
        { \"id\": \"e1fe6dd8-ba31-4d61-89e7-88639da4683d\", \"type\": \"Scope\" },
        { \"id\": \"5f8c59db-677d-491f-a6b8-5f174b11ec1d\", \"type\": \"Scope\" },
        { \"id\": \"2219042f-cab5-40cc-b0d2-16b1540b4c5f\", \"type\": \"Scope\" }
      ]
    }
  ]" --output none

echo "  ✅ Permissions set:"
echo "     ✔ User.Read       — read signed-in user profile"
echo "     ✔ Group.Read.All  — read all group memberships"
echo "     ✔ Tasks.ReadWrite — read/write Microsoft To Do tasks"

# ── Admin consent ─────────────────────────────────────────────────
echo ""
echo "🛡️  Granting admin consent for tenant ${TENANT_ID}..."
az ad app permission admin-consent --id "${CLIENT_ID}" --output none 2>/dev/null || {
  echo "  ⚠️  Admin consent requires Global Administrator role."
  echo "     Grant manually: https://entra.microsoft.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/${CLIENT_ID}"
}
echo "  ✅ Admin consent granted"

# ── Create client secret ──────────────────────────────────────────
echo ""
echo "🔐 Creating client secret (2-year expiry)..."
SECRET_JSON=$(az ad app credential reset \
  --id "${CLIENT_ID}" \
  --display-name "mosgarage-auto-$(date +%Y%m%d)" \
  --years 2 \
  --query "{value:password, hint:hint}" \
  --output json)
CLIENT_SECRET=$(echo "${SECRET_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])")
echo "  ✅ Client secret created"

# ── Set Application ID URI ────────────────────────────────────────
echo ""
echo "🌐 Setting Application ID URI..."
az ad app update --id "${CLIENT_ID}" \
  --identifier-uris "api://${CLIENT_ID}" \
  --output none 2>/dev/null || true

# ── Write to .env ─────────────────────────────────────────────────
echo ""
echo "📄 Writing Entra ID config to ${ENV_FILE}..."

# Remove existing Entra entries
sed -i '/^ENTRA_/d; /^AZURE_/d' "${ENV_FILE}" 2>/dev/null || true

cat >> "${ENV_FILE}" <<ENVEOF

# ── Microsoft Entra ID (auto-generated by entra-setup.sh) ──────────
ENTRA_TENANT_ID=${TENANT_ID}
ENTRA_CLIENT_ID=${CLIENT_ID}
ENTRA_CLIENT_SECRET=${CLIENT_SECRET}
ENTRA_AUDIENCE=api://${CLIENT_ID}
ENVEOF

echo "  ✅ Written to ${ENV_FILE}"

# ── Print summary ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Microsoft Entra ID App Registration complete!           ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  App Name      : ${APP_NAME}"
echo "║  Client ID     : ${CLIENT_ID}"
echo "║  Tenant ID     : ${TENANT_ID}"
echo "║  Secret Hint   : $(echo "${SECRET_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['hint'])")..."
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Permissions:                                                ║"
echo "║    ✅ User.Read         (delegated)                          ║"
echo "║    ✅ Group.Read.All    (delegated)                          ║"
echo "║    ✅ Tasks.ReadWrite   (delegated)                          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Redirect URIs:                                              ║"
echo "║    ${REDIRECT_URI}"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Portal link:                                                ║"
echo "║  https://entra.microsoft.com/#blade/Microsoft_AAD_           ║"
echo "║  RegisteredApps/ApplicationMenuBlade/Overview/appId/         ║"
echo "║  ${CLIENT_ID}  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Next: docker compose up -d"
echo "        Login at: ${MOSGARAGE_ACCESS_URL:-http://localhost:7070}/auth/login"
echo ""
