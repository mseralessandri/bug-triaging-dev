#!/usr/bin/env bash
# Create or update a Jira bug from a jira-writer JSON payload.
#
# Idempotent: if an issue tagged with gh-<issue_id> already exists in the
# project it is updated (PUT) instead of creating a duplicate (POST).
#
# Usage:
#   ./scripts/jira-create-issue.sh --payload <file.json> --epic-key LXD-XXX [--confirm]
#
# By default runs in dry-run mode and prints what would be sent.
# Pass --confirm to actually call the Jira API.
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

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

PAYLOAD_FILE=""
EPIC_KEY=""
CONFIRM="false"

usage() {
  cat <<EOF
Usage:
  $0 --payload <file.json> --epic-key <EPIC-KEY> [--confirm]

  --payload FILE    Path to jira-writer output JSON
  --epic-key KEY    Jira Epic key to link this bug to (e.g. LXD-42)
  --confirm         Actually send to Jira (default: dry-run)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --payload)  PAYLOAD_FILE="$2"; shift 2 ;;
    --epic-key) EPIC_KEY="$2";     shift 2 ;;
    --confirm)  CONFIRM="true";    shift   ;;
    --help|-h)  usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$PAYLOAD_FILE" || -z "$EPIC_KEY" ]]; then
  echo "Error: --payload and --epic-key are required." >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$PAYLOAD_FILE" ]]; then
  echo "Error: payload file not found: $PAYLOAD_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse jira-writer output
# ---------------------------------------------------------------------------

MODE=$(jq -r '.mode' "$PAYLOAD_FILE")
if [[ "$MODE" != "create" ]]; then
  SKIP_REASON=$(jq -r '.skip_reason // "jira_required is false"' "$PAYLOAD_FILE")
  echo "Skipping: $SKIP_REASON"
  exit 0
fi

SUMMARY=$(jq -r   '.jira_payload.summary'              "$PAYLOAD_FILE")
DESCRIPTION=$(jq -r '.jira_payload.description'        "$PAYLOAD_FILE")
LABELS=$(jq -c    '.jira_payload.labels'               "$PAYLOAD_FILE")
COMPONENT=$(jq -r '.jira_payload.fields.component'     "$PAYLOAD_FILE")
SEVERITY=$(jq -r  '.jira_payload.fields.severity_score' "$PAYLOAD_FILE")
PRIORITY_LEVEL=$(jq -r '.jira_payload.fields.priority_level' "$PAYLOAD_FILE")
SOURCE_ID=$(jq -r '.jira_payload.fields.source_issue_id' "$PAYLOAD_FILE")
SOURCE_URL=$(jq -r '.jira_payload.fields.source_issue_url // ""' "$PAYLOAD_FILE")
RANK_SCORE=$(jq -r '.jira_payload.fields.rank_score'   "$PAYLOAD_FILE")

# Idempotency: search by source_issue_id in custom field instead of label
# No gh- labels needed anymore

# ---------------------------------------------------------------------------
# Priority mapping: triage P0-P4 → Jira priority names
# ---------------------------------------------------------------------------

map_priority() {
  case "$1" in
    P0) echo "Highest" ;;
    P1) echo "High"    ;;
    P2) echo "Medium"  ;;
    P3) echo "Low"     ;;
    P4) echo "Lowest"  ;;
    *)  echo "Medium"  ;;
  esac
}

JIRA_PRIORITY=$(map_priority "$PRIORITY_LEVEL")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

AUTH_HEADER="Authorization: Basic $(printf '%s:%s' "$JIRA_USER" "$JIRA_API_TOKEN" | base64 -w0)"
BASE="${JIRA_BASE_URL}/rest/api/3"

jira_search() {
  local jql="$1"
  local payload
  payload=$(jq -n --arg jql "$jql" '{jql: $jql, fields: ["key", "summary"], maxResults: 1}')
  curl -fsSL -X POST \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "${BASE}/search/jql"
}

jira_create() {
  local body="$1"
  curl -fsSL -X POST \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${BASE}/issue"
}

jira_update() {
  local key="$1"
  local body="$2"
  curl -fsSL -X PUT \
    -H "$AUTH_HEADER" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${BASE}/issue/${key}"
}

# ---------------------------------------------------------------------------
# Build ADF description (Atlassian Document Format, required by REST API v3)
# ---------------------------------------------------------------------------

# Build ADF description with proper formatting
# Uses heading, paragraphs, code blocks, and links
build_adf_description() {
  local description="$1"
  local github_url="$2"
  local github_id="$3"
  
  # Split description into sections and format properly
  python3 -c "
import json
import sys

desc = '''$description'''
github_url = '$github_url'
github_id = '$github_id'

# Build ADF document
adf = {
    'version': 1,
    'type': 'doc',
    'content': []
}

# Add GitHub link at the top
if github_url:
    adf['content'].append({
        'type': 'paragraph',
        'content': [
            {'type': 'text', 'text': '🔗 '},
            {
                'type': 'text',
                'text': f'GitHub Issue #{github_id}',
                'marks': [
                    {
                        'type': 'link',
                        'attrs': {'href': github_url}
                    },
                    {'type': 'strong'}
                ]
            }
        ]
    })
    adf['content'].append({'type': 'rule'})

# Split description by markdown headings and format
lines = desc.split('\n')
current_paragraph = []

for line in lines:
    if line.startswith('**') and line.endswith('**'):
        # Flush current paragraph
        if current_paragraph:
            text = '\n'.join(current_paragraph)
            if text.strip():
                adf['content'].append({
                    'type': 'paragraph',
                    'content': [{'type': 'text', 'text': text}]
                })
            current_paragraph = []
        
        # Add heading
        heading_text = line.strip('*').strip()
        adf['content'].append({
            'type': 'heading',
            'attrs': {'level': 2},
            'content': [{'type': 'text', 'text': heading_text}]
        })
    elif line.startswith('| ') and '|' in line:
        # Table row - add to paragraph (simplified)
        current_paragraph.append(line)
    else:
        current_paragraph.append(line)

# Flush remaining paragraph
if current_paragraph:
    text = '\n'.join(current_paragraph)
    if text.strip():
        adf['content'].append({
            'type': 'paragraph',
            'content': [{'type': 'text', 'text': text}]
        })

print(json.dumps(adf))
"
}

ADF_DESCRIPTION=$(build_adf_description "$DESCRIPTION" "$SOURCE_URL" "$SOURCE_ID")

# ---------------------------------------------------------------------------
# Build issue body
# ---------------------------------------------------------------------------

build_create_body() {
  if [[ -n "$EPIC_KEY" ]]; then
    jq -n \
      --arg project    "$JIRA_PROJECT_KEY" \
      --arg summary    "$SUMMARY" \
      --argjson desc   "$ADF_DESCRIPTION" \
      --argjson labels "$LABELS" \
      --arg priority   "$JIRA_PRIORITY" \
      --arg component  "$COMPONENT" \
      --arg epic       "$EPIC_KEY" \
      '{
        "fields": {
          "project":     {"key": $project},
          "issuetype":   {"name": "Bug"},
          "summary":     $summary,
          "description": $desc,
          "labels":      $labels,
          "priority":    {"name": $priority},
          "components":  [{"name": $component}],
          "customfield_10014": $epic
        }
      }'
  else
    jq -n \
      --arg project    "$JIRA_PROJECT_KEY" \
      --arg summary    "$SUMMARY" \
      --argjson desc   "$ADF_DESCRIPTION" \
      --argjson labels "$LABELS" \
      --arg priority   "$JIRA_PRIORITY" \
      --arg component  "$COMPONENT" \
      '{
        "fields": {
          "project":     {"key": $project},
          "issuetype":   {"name": "Bug"},
          "summary":     $summary,
          "description": $desc,
          "labels":      $labels,
          "priority":    {"name": $priority},
          "components":  [{"name": $component}]
        }
      }'
  fi
}

build_update_body() {
  jq -n \
    --arg summary   "$SUMMARY" \
    --argjson desc  "$ADF_DESCRIPTION" \
    --argjson labels "$LABELS" \
    --arg priority  "$JIRA_PRIORITY" \
    --arg component "$COMPONENT" \
    '{
      "fields": {
        "summary":     $summary,
        "description": $desc,
        "labels":      $labels,
        "priority":    {"name": $priority},
        "components":  [{"name": $component}]
      }
    }'
}

# ---------------------------------------------------------------------------
# Dry-run output
# ---------------------------------------------------------------------------

if [[ "$CONFIRM" != "true" ]]; then
  echo ""
  echo "=== DRY RUN (pass --confirm to apply) ==="
  echo "  Source issue : #${SOURCE_ID}  ${SOURCE_URL}"
  echo "  Summary      : $SUMMARY"
  echo "  Priority     : $PRIORITY_LEVEL → $JIRA_PRIORITY"
  echo "  Component    : $COMPONENT"
  echo "  Severity     : $SEVERITY"
  echo "  Rank score   : $RANK_SCORE"
  echo "  Epic         : $EPIC_KEY"
  echo "  Labels       : $(echo "$LABELS" | jq -r 'join(", ")')"
  echo "  Action       : CREATE or UPDATE (idempotency check runs only with --confirm)"
  echo ""
  echo "  Create body:"
  build_create_body | jq .
  exit 0
fi

# ---------------------------------------------------------------------------
# Apply (idempotency check only runs here)
# ---------------------------------------------------------------------------

echo "Checking for existing issue with source: $SOURCE_URL ..."
# Search by summary containing the GitHub issue number for idempotency
SEARCH_RESULT=$(jira_search "project=${JIRA_PROJECT_KEY} AND summary ~ \"#${SOURCE_ID}\"")
EXISTING_KEY=$(echo "$SEARCH_RESULT" | jq -r '.issues[0].key // empty')

if [[ -n "$EXISTING_KEY" ]]; then
  echo "Found existing issue $EXISTING_KEY — updating..."
  UPDATE_BODY=$(build_update_body)
  jira_update "$EXISTING_KEY" "$UPDATE_BODY"
  echo "Updated: ${JIRA_BASE_URL}/browse/${EXISTING_KEY}"
else
  echo "No existing issue found — creating..."
  CREATE_BODY=$(build_create_body)
  RESULT=$(jira_create "$CREATE_BODY")
  NEW_KEY=$(echo "$RESULT" | jq -r '.key')
  echo "Created: ${JIRA_BASE_URL}/browse/${NEW_KEY}"
fi
