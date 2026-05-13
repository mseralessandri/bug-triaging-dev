#!/usr/bin/env bash
# Store Jira credentials inside the workshop, analogous to gh auth login.
# Run once inside the workshop: ./scripts/jira-auth.sh
#
# Credentials are saved to ~/.config/jira/credentials (never in the repo).

set -euo pipefail

CREDS_DIR="$HOME/.config/jira"
CREDS_FILE="$CREDS_DIR/credentials"

mkdir -p "$CREDS_DIR"
chmod 700 "$CREDS_DIR"

# Show current status if already configured.
if [[ -f "$CREDS_FILE" ]]; then
  existing_user=$(grep '^user=' "$CREDS_FILE" | cut -d= -f2- | tr -d '[:space:]')
  existing_url=$(grep '^base_url=' "$CREDS_FILE" | cut -d= -f2- | tr -d '[:space:]')
  echo "Already logged in to $existing_url as $existing_user"
  read -rp "Re-authenticate? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

read -rp "Jira base URL [https://warthogs-sandbox.atlassian.net]: " base_url
base_url="${base_url:-https://warthogs-sandbox.atlassian.net}"

read -rp "Jira project key [LXD]: " project_key
project_key="${project_key:-LXD}"

read -rp "Email: " user

read -rsp "API token (https://id.atlassian.com/manage-profile/security/api-tokens): " api_token
echo

# Validate credentials before saving.
echo "Validating..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "${user}:${api_token}" \
  "${base_url}/rest/api/3/myself")

if [[ "$http_code" != "200" ]]; then
  echo "Error: authentication failed (HTTP $http_code). Check your email and API token." >&2
  exit 1
fi

cat > "$CREDS_FILE" <<EOF
base_url=${base_url}
project_key=${project_key}
user=${user}
api_token=${api_token}
EOF
chmod 600 "$CREDS_FILE"

echo "✓ Logged in to ${base_url} as ${user}"
