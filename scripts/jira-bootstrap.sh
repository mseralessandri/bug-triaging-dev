#!/usr/bin/env bash
# Bootstrap Jira project for LXD triage: create components and labels.
# Safe to re-run: skips anything that already exists.
#
# Usage:
#   ./scripts/jira-bootstrap.sh [--dry-run]
#
# Requirements: curl, jq
# Auth: run ./scripts/jira-auth.sh once inside the workshop (like gh auth login).

set -euo pipefail

CREDS_FILE="${HOME}/.config/jira/credentials"
if [[ ! -f "$CREDS_FILE" ]]; then
  echo "Error: not authenticated. Run once inside the workshop:" >&2
  echo "  ./scripts/jira-auth.sh" >&2
  exit 1
fi

JIRA_BASE_URL=$(grep '^base_url=' "$CREDS_FILE" | cut -d= -f2- | tr -d '[:space:]')
JIRA_PROJECT_KEY=$(grep '^project_key=' "$CREDS_FILE" | cut -d= -f2- | tr -d '[:space:]')
JIRA_USER=$(grep '^user=' "$CREDS_FILE" | cut -d= -f2- | tr -d '[:space:]')
JIRA_API_TOKEN=$(grep '^api_token=' "$CREDS_FILE" | cut -d= -f2- | tr -d '[:space:]')

DRY_RUN="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

AUTH_HEADER="Authorization: Basic $(printf '%s:%s' "$JIRA_USER" "$JIRA_API_TOKEN" | base64 -w0)"
BASE="${JIRA_BASE_URL}/rest/api/3"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

jira_get() {
  curl -fsSL -H "$AUTH_HEADER" -H "Content-Type: application/json" "$BASE/$1"
}

jira_post() {
  local path="$1"
  local body="$2"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] POST $BASE/$path"
    echo "$body" | jq .
    return 0
  fi
  local response http_code body_out
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "$BASE/$path" 2>&1) || true
  http_code=$(tail -1 <<< "$response")
  body_out=$(head -n -1 <<< "$response")
  
  if [[ "$http_code" == "201" || "$http_code" == "200" ]]; then
    echo "$body_out"
    return 0
  elif [[ "$http_code" == "400" ]]; then
    local errors
    errors=$(echo "$body_out" | jq -r '.errors | to_entries[] | .value' 2>/dev/null || echo "already exists or invalid request")
    echo "  [skip] $errors" >&2
    return 0
  else
    echo "  [error] HTTP $http_code: $body_out" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Components
# All 14 canonical components from the triage taxonomy.
# ---------------------------------------------------------------------------

COMPONENTS=(
  "compute:Instance, VM, Container, Snapshots, Backups, Exec, Console, Migration"
  "storage:Storage Pool, Volume, Snapshot, Backup, Bucket, Drivers (ZFS/LVM/Ceph)"
  "networking:Network, ACL, Forward, Load Balancer, Peer, Zone, DNS, DHCP, OVN, BGP"
  "images:Image, Image Alias, Templates, Simplestreams"
  "projects:Project, Multi-tenancy, Resource Isolation"
  "profiles:Profile, Configuration Templates, Inheritance"
  "clustering:Cluster, Member, Group, Link, Replicator, Dqlite, Raft"
  "auth:Certificate, Identity, Auth Group, OIDC, OpenFGA, RBAC, ACME"
  "api-server:REST API, Server Config, Operations, Warnings, Events, Metrics, DevLXD"
  "database:Dqlite, Schema, Migrations, Patches, Queries"
  "devices:Device Drivers: GPU, USB, Proxy, Disk, NIC, TPM, PCI, Hotplug"
  "packaging:Snap Packaging, Systemd Integration, Service Dependencies"
  "documentation:Documentation, Help Text, Man Pages"
  "unknown:Cannot determine with confidence or outside scope"
)

echo "=== Components ==="
echo "  Project : ${JIRA_PROJECT_KEY}"
echo "  User    : ${JIRA_USER}"
echo ""

# Fetch existing components once — also validates auth and project key.
# In dry-run we still fetch so the skip logic works correctly.
EXISTING_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "$AUTH_HEADER" -H "Content-Type: application/json" \
  "${BASE}/project/${JIRA_PROJECT_KEY}/components")
HTTP_CODE=$(tail -1 <<< "$EXISTING_RESPONSE")
EXISTING_BODY=$(head -n -1 <<< "$EXISTING_RESPONSE")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error: GET /project/${JIRA_PROJECT_KEY}/components returned HTTP $HTTP_CODE" >&2
  echo "Check that project key '${JIRA_PROJECT_KEY}' exists and your token is valid." >&2
  exit 1
fi
EXISTING_COMPONENTS=$(jq -r '.[].name' <<< "$EXISTING_BODY")

for entry in "${COMPONENTS[@]}"; do
  name="${entry%%:*}"
  description="${entry#*:}"

  if echo "$EXISTING_COMPONENTS" | grep -qx "$name"; then
    echo "  [skip] component already exists: $name"
    continue
  fi

  echo "  [create] component: $name"
  body=$(jq -n \
    --arg project "$JIRA_PROJECT_KEY" \
    --arg name "$name" \
    --arg desc "$description" \
    '{"project": $project, "name": $name, "description": $desc}')
  result=$(jira_post "component" "$body") || {
    echo "  -> failed to create $name"
    continue
  }
  created=$(echo "$result" | jq -r '.name // empty' 2>/dev/null)
  if [[ -n "$created" ]]; then
    echo "  -> created: $created"
  fi
done

# ---------------------------------------------------------------------------
# Labels
# Labels in Jira are global (not per-project) and cannot be pre-created via API —
# they are created automatically on first use. We document them here and create
# a reference issue comment instead.
# ---------------------------------------------------------------------------

echo ""
echo "=== Labels (applied automatically on issue creation) ==="
echo "  triage-bot"
for i in $(seq 1 10); do echo "  severity-$i"; done
for p in p0 p1 p2 p3 p4; do echo "  priority-$p"; done
echo ""
echo "Note: Jira labels are global and created on first use. No pre-creation needed."
echo "      They will appear in the project after the first issue is created."

echo ""
echo "Bootstrap complete."
